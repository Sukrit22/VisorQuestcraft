import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import pojlib.account.Msa;
import pojlib.util.Constants;

public class AuthProfileTest {
    static int status;
    static HttpURLConnection last;
    public static void main(String[] args) throws Exception {
        Constants.USER_HOME = Files.createTempDirectory("visor-auth-test-").toString();
        URL.setURLStreamHandlerFactory(protocol -> "https".equals(protocol) ? new URLStreamHandler() {
            protected URLConnection openConnection(URL url) {
                if (!url.getPath().equals("/minecraft/profile")) throw new AssertionError("Unexpected auth request");
                last = new HttpURLConnection(url) {
                    public void connect() { }
                    public void disconnect() { }
                    public boolean usingProxy() { return false; }
                    public int getResponseCode() { return status; }
                    public InputStream getInputStream() {
                        return new ByteArrayInputStream("{\"name\":\"TestPlayer\",\"id\":\"0123456789abcdef0123456789abcdef\"}".getBytes(StandardCharsets.UTF_8));
                    }
                };
                return last;
            }
        } : null);
        for (int code : new int[] {200, 404, 401, 403, 429, 500, 503}) {
            status = code;
            Msa msa = new Msa(null);
            try {
                boolean owned = msa.checkMcProfile("synthetic-test-token");
                if (code != 200 && code != 404) throw new AssertionError("HTTP " + code + " silently became demo");
                if (owned != (code == 200) || msa.doesOwnGame != owned) throw new AssertionError("Wrong ownership result");
            } catch (IOException error) {
                if (code == 200 || code == 404) throw error;
            }
            if (last.getConnectTimeout() != 15000 || last.getReadTimeout() != 30000) throw new AssertionError("Unbounded profile request");
            System.out.println("PASS profile response HTTP " + code);
        }
        pojlib.util.Logger.getInstance().shutdown();
        Files.deleteIfExists(Path.of(Constants.USER_HOME, "latestlog.txt"));
        Files.delete(Path.of(Constants.USER_HOME));
    }
}
