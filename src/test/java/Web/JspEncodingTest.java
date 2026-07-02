package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertTrue;

class JspEncodingTest {
    private static final Path WEBAPP = Path.of("src/main/webapp");

    @Test
    void everyStandaloneJspDeclaresUtf8SourceEncoding() throws Exception {
        List<Path> missingEncoding;
        try (var paths = Files.walk(WEBAPP)) {
            missingEncoding = paths
                    .filter(path -> path.toString().endsWith(".jsp"))
                    .filter(path -> !path.startsWith(WEBAPP.resolve("includes")))
                    .filter(path -> {
                        try {
                            return !Files.readString(path, StandardCharsets.UTF_8)
                                    .contains("pageEncoding=\"UTF-8\"");
                        } catch (Exception exception) {
                            throw new RuntimeException(exception);
                        }
                    })
                    .collect(Collectors.toList());
        }

        assertTrue(missingEncoding.isEmpty(),
                "JSP files without an explicit UTF-8 pageEncoding: " + missingEncoding);
    }

    @Test
    void webXmlDefinesUtf8AsTheJspDefault() throws Exception {
        String webXml = Files.readString(WEBAPP.resolve("WEB-INF/web.xml"), StandardCharsets.UTF_8);

        assertTrue(webXml.contains("<page-encoding>UTF-8</page-encoding>"));
        assertTrue(webXml.contains("<default-content-type>text/html; charset=UTF-8</default-content-type>"));
    }
}
