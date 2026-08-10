package AccessCounter;

import com.maxmind.geoip2.DatabaseReader;
import com.maxmind.geoip2.model.AsnResponse;
import com.maxmind.geoip2.model.CityResponse;
import com.maxmind.geoip2.model.CountryResponse;
import com.maxmind.geoip2.record.Location;
import com.maxmind.geoip2.record.Subdivision;

import javax.servlet.http.HttpServletRequest;
import java.io.Closeable;
import java.io.IOException;
import java.net.InetAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;

/** Local-only country lookup for the protected developer analytics view. */
final class CountryResolver implements Closeable {
    private final DatabaseReader cityDatabase;
    private final DatabaseReader asnDatabase;
    private final Map<String, VisitorLocation> addressCache = new LinkedHashMap<String, VisitorLocation>(128, .75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, VisitorLocation> eldest) {
            return size() > 10000;
        }
    };

    private CountryResolver(DatabaseReader cityDatabase, DatabaseReader asnDatabase) {
        this.cityDatabase = cityDatabase;
        this.asnDatabase = asnDatabase;
    }

    static CountryResolver open(Path databasePath) throws IOException {
        return open(databasePath, null);
    }

    static CountryResolver open(Path cityDatabasePath, Path asnDatabasePath) throws IOException {
        DatabaseReader city = openDatabase(cityDatabasePath);
        DatabaseReader asn = null;
        try {
            asn = openDatabase(asnDatabasePath);
        } catch (IOException ignored) {
            // ASN enrichment is optional and must never disable city/country lookup.
        }
        if (city == null && asn == null) return null;
        return new CountryResolver(city, asn);
    }

    private static DatabaseReader openDatabase(Path path) throws IOException {
        if (path == null || !Files.isRegularFile(path)) return null;
        return new DatabaseReader.Builder(path.toFile()).build();
    }

    VisitorLocation resolve(HttpServletRequest request) {
        VisitorLocation location = locate(request);
        if (!location.hasPublicAddress()) return location;
        return resolveAddress(location.getAddress());
    }

    boolean hasAsnDatabase() { return asnDatabase != null; }

    VisitorLocation resolveAddress(String address) {
        if (!isPublicLiteralIp(address)) return VisitorLocation.unavailable();
        synchronized (addressCache) {
            VisitorLocation cached = addressCache.get(address);
            if (cached != null) return cached;
        }
        VisitorLocation location = new VisitorLocation(address.trim(), "ZZ");
        try {
            InetAddress inetAddress = InetAddress.getByName(location.getAddress());
            if (!isPublic(inetAddress)) return VisitorLocation.unavailable();
            String country = location.getCountry();
            String regionCode = "";
            String regionName = "";
            String cityName = "";
            Integer accuracyRadiusKm = null;
            if (cityDatabase != null) {
                try {
                    CityResponse response = cityDatabase.city(inetAddress);
                    country = CountryTrafficStore.normalizeCountry(response.getCountry().getIsoCode());
                    Subdivision subdivision = response.getMostSpecificSubdivision();
                    regionCode = normalizeSubdivisionCode(subdivision == null ? null : subdivision.getIsoCode());
                    regionName = normalizeSubdivisionName(subdivision == null ? null : subdivision.getName());
                    cityName = normalizePlaceName(response.getCity() == null ? null : response.getCity().getName());
                    Location resolvedLocation = response.getLocation();
                    accuracyRadiusKm = resolvedLocation == null ? null : resolvedLocation.getAccuracyRadius();
                } catch (Exception ignored) {
                    // A country-only MaxMind database can still support country
                    // analytics even when city records are unavailable.
                    try {
                        CountryResponse response = cityDatabase.country(inetAddress);
                        country = CountryTrafficStore.normalizeCountry(response.getCountry().getIsoCode());
                    } catch (Exception ignoredCountryLookup) {
                        // Leave the country unavailable rather than guessing.
                    }
                }
            }

            String asnNumber = "";
            String networkOrganization = "";
            if (asnDatabase != null) {
                try {
                    AsnResponse response = asnDatabase.asn(inetAddress);
                    if (response.getAutonomousSystemNumber() != null) {
                        asnNumber = String.valueOf(response.getAutonomousSystemNumber());
                    }
                    networkOrganization = normalizeNetworkOrganization(
                            response.getAutonomousSystemOrganization());
                } catch (Exception ignored) {
                    // Not every address has an ASN record, and an optional ASN
                    // database problem must not discard valid city evidence.
                }
            }
            VisitorLocation resolved = new VisitorLocation(location.getAddress(), country, regionCode, regionName,
                    cityName, accuracyRadiusKm, accuracyLabel(country, regionName, cityName, accuracyRadiusKm),
                    asnNumber, networkOrganization);
            synchronized (addressCache) { addressCache.put(address, resolved); }
            return resolved;
        } catch (Exception ignored) {
            // Address capture and country lookup are deliberately independent:
            // a stale/missing local database must not hide the developer-only
            // address diagnostic needed to repair the lookup.
            return location;
        }
    }

    static VisitorLocation locate(HttpServletRequest request) {
        String address = clientAddress(request);
        return address == null ? VisitorLocation.unavailable() : new VisitorLocation(address, "ZZ");
    }

    /**
     * Nginx is the only permitted proxy. It overwrites X-Real-IP before passing
     * requests to loopback Tomcat; direct requests therefore cannot choose a
     * country by injecting this header.
     */
    private static String clientAddress(HttpServletRequest request) {
        String remote = request.getRemoteAddr();
        if (isLoopback(remote)) {
            String proxied = request.getHeader("X-Real-IP");
            if (isPublicLiteralIp(proxied)) return proxied.trim();
            String forwarded = rightmostPublicForwardedAddress(request.getHeader("X-Forwarded-For"));
            if (forwarded != null) return forwarded;
        }
        return isPublicLiteralIp(remote) ? remote.trim() : null;
    }

    private static boolean isLoopback(String value) {
        if (!isLiteralIp(value)) return false;
        try {
            return InetAddress.getByName(value.trim()).isLoopbackAddress();
        } catch (Exception ignored) {
            return false;
        }
    }

    private static boolean isLiteralIp(String value) {
        return value != null && value.trim().length() <= 64
                && value.trim().matches("[0-9A-Fa-f:.]+");
    }

    private static boolean isPublicLiteralIp(String value) {
        if (!isLiteralIp(value)) return false;
        try { return isPublic(InetAddress.getByName(value.trim())); }
        catch (Exception ignored) { return false; }
    }

    private static String rightmostPublicForwardedAddress(String value) {
        if (value == null || value.length() > 1024) return null;
        String[] addresses = value.split(",");
        for (int i = addresses.length - 1; i >= 0; i--) {
            String candidate = addresses[i].trim();
            if (isPublicLiteralIp(candidate)) return candidate;
        }
        return null;
    }

    private static boolean isPublic(InetAddress address) {
        if (address.isAnyLocalAddress() || address.isLoopbackAddress()
                || address.isLinkLocalAddress() || address.isSiteLocalAddress()
                || address.isMulticastAddress()) return false;
        byte[] bytes = address.getAddress();
        if (bytes.length == 4) {
            int first = Byte.toUnsignedInt(bytes[0]);
            int second = Byte.toUnsignedInt(bytes[1]);
            return first != 0 && first != 10 && first != 127
                    && !(first == 100 && second >= 64 && second <= 127)
                    && !(first == 169 && second == 254)
                    && !(first == 172 && second >= 16 && second <= 31)
                    && !(first == 192 && second == 168);
        }
        return (bytes[0] & 0xfe) != 0xfc;
    }

    static final class VisitorLocation {
        private final String address;
        private final String country;
        private final String regionCode;
        private final String regionName;
        private final String cityName;
        private final Integer accuracyRadiusKm;
        private final String accuracyLabel;
        private final String asnNumber;
        private final String networkOrganization;

        VisitorLocation(String address, String country) {
            this(address, country, "", "");
        }

        VisitorLocation(String address, String country, String regionCode, String regionName) {
            this(address, country, regionCode, regionName, "", null,
                    accuracyLabel(country, regionName, "", null), "", "");
        }

        VisitorLocation(String address, String country, String regionCode, String regionName,
                        String cityName, Integer accuracyRadiusKm, String accuracyLabel,
                        String asnNumber, String networkOrganization) {
            this.address = address;
            this.country = country;
            this.regionCode = regionCode == null ? "" : regionCode;
            this.regionName = regionName == null ? "" : regionName;
            this.cityName = cityName == null ? "" : cityName;
            this.accuracyRadiusKm = accuracyRadiusKm;
            this.accuracyLabel = accuracyLabel == null ? "" : accuracyLabel;
            this.asnNumber = asnNumber == null ? "" : asnNumber;
            this.networkOrganization = networkOrganization == null ? "" : networkOrganization;
        }

        static VisitorLocation unavailable() { return new VisitorLocation(null, "ZZ"); }
        boolean hasPublicAddress() { return address != null; }
        String getAddress() { return address; }
        String getCountry() { return country; }
        String getRegionCode() { return regionCode; }
        String getRegionName() { return regionName; }
        String getCityName() { return cityName; }
        Integer getAccuracyRadiusKm() { return accuracyRadiusKm; }
        String getAccuracyLabel() { return accuracyLabel; }
        String getAsnNumber() { return asnNumber; }
        String getNetworkOrganization() { return networkOrganization; }
    }

    private static String normalizeSubdivisionCode(String value) {
        if (value == null) return "";
        String normalized = value.trim();
        return normalized.length() > 24 ? normalized.substring(0, 24) : normalized;
    }

    private static String normalizeSubdivisionName(String value) {
        if (value == null) return "";
        String normalized = value.replaceAll("[\\r\\n\\t]", " ").trim();
        return normalized.length() > 80 ? normalized.substring(0, 80) : normalized;
    }

    private static String normalizePlaceName(String value) {
        if (value == null) return "";
        String normalized = value.replaceAll("[\\r\\n\\t]", " ").trim();
        return normalized.length() > 100 ? normalized.substring(0, 100) : normalized;
    }

    private static String normalizeNetworkOrganization(String value) {
        if (value == null) return "";
        String normalized = value.replaceAll("[\\r\\n\\t]", " ").trim();
        return normalized.length() > 160 ? normalized.substring(0, 160) : normalized;
    }

    private static String accuracyLabel(String country, String regionName, String cityName,
                                        Integer accuracyRadiusKm) {
        if (cityName != null && !cityName.isBlank() && accuracyRadiusKm != null) {
            return "Approximate city · 67% confidence radius " + accuracyRadiusKm + " km";
        }
        if (cityName != null && !cityName.isBlank()) return "Approximate city";
        if (regionName != null && !regionName.isBlank()) return "Region-level estimate";
        if (country != null && !"ZZ".equals(country)) return "Country-level estimate";
        return "Unavailable";
    }

    @Override
    public void close() throws IOException {
        IOException failure = null;
        if (cityDatabase != null) {
            try { cityDatabase.close(); }
            catch (IOException error) { failure = error; }
        }
        if (asnDatabase != null) {
            try { asnDatabase.close(); }
            catch (IOException error) { if (failure == null) failure = error; }
        }
        if (failure != null) throw failure;
    }
}
