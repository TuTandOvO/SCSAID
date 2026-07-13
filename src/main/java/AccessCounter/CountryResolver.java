package AccessCounter;

import com.maxmind.geoip2.DatabaseReader;
import com.maxmind.geoip2.exception.AddressNotFoundException;
import com.maxmind.geoip2.model.CountryResponse;

import javax.servlet.http.HttpServletRequest;
import java.io.Closeable;
import java.io.IOException;
import java.net.InetAddress;
import java.nio.file.Files;
import java.nio.file.Path;

/** Local-only country lookup for the protected developer analytics view. */
final class CountryResolver implements Closeable {
    private final DatabaseReader database;

    private CountryResolver(DatabaseReader database) {
        this.database = database;
    }

    static CountryResolver open(Path databasePath) throws IOException {
        if (databasePath == null || !Files.isRegularFile(databasePath)) return null;
        return new CountryResolver(new DatabaseReader.Builder(databasePath.toFile()).build());
    }

    VisitorLocation resolve(HttpServletRequest request) {
        VisitorLocation location = locate(request);
        if (!location.hasPublicAddress()) return location;
        try {
            InetAddress inetAddress = InetAddress.getByName(location.getAddress());
            if (!isPublic(inetAddress)) return VisitorLocation.unavailable();
            CountryResponse response = database.country(inetAddress);
            return new VisitorLocation(location.getAddress(),
                    CountryTrafficStore.normalizeCountry(response.getCountry().getIsoCode()));
        } catch (AddressNotFoundException ignored) {
            return location;
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

        VisitorLocation(String address, String country) {
            this.address = address;
            this.country = country;
        }

        static VisitorLocation unavailable() { return new VisitorLocation(null, "ZZ"); }
        boolean hasPublicAddress() { return address != null; }
        String getAddress() { return address; }
        String getCountry() { return country; }
    }

    @Override
    public void close() throws IOException {
        database.close();
    }
}
