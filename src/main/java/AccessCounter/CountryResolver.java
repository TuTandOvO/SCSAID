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

/** Local-only country lookup. The resolved IP is never written to disk or logs. */
final class CountryResolver implements Closeable {
    private final DatabaseReader database;

    private CountryResolver(DatabaseReader database) {
        this.database = database;
    }

    static CountryResolver open(Path databasePath) throws IOException {
        if (databasePath == null || !Files.isRegularFile(databasePath)) return null;
        return new CountryResolver(new DatabaseReader.Builder(databasePath.toFile()).build());
    }

    String resolve(HttpServletRequest request) {
        String address = clientAddress(request);
        if (address == null) return "ZZ";
        try {
            InetAddress inetAddress = InetAddress.getByName(address);
            if (inetAddress.isAnyLocalAddress() || inetAddress.isLoopbackAddress()
                    || inetAddress.isLinkLocalAddress() || inetAddress.isSiteLocalAddress()) {
                return "ZZ";
            }
            CountryResponse response = database.country(inetAddress);
            return CountryTrafficStore.normalizeCountry(response.getCountry().getIsoCode());
        } catch (AddressNotFoundException ignored) {
            return "ZZ";
        } catch (Exception ignored) {
            // Country telemetry is optional and must never interfere with page delivery.
            return "ZZ";
        }
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
            if (isLiteralIp(proxied)) return proxied.trim();
        }
        return isLiteralIp(remote) ? remote.trim() : null;
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

    @Override
    public void close() throws IOException {
        database.close();
    }
}
