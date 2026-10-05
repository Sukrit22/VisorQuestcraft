import me.phoenixra.atumvr.core.session.platform.AndroidXRBridge;
import me.phoenixra.atumvr.core.session.platform.XRPlatform;

public class BridgeDiscoveryTest {
    public static class ExtraBridge implements AndroidXRBridge {
        public long getEGLDisplay() { return 0; }
        public long getEGLContext() { return 0; }
        public long getEGLConfig() { return 0; }
        public long getDalvikVM() { return 0; }
        public long getDalvikActivity() { return 0; }
        public void setupAndroid() { throw new AssertionError("Discovery must not start native XR"); }
    }
    public static void main(String[] args) {
        String mode = args[0];
        System.setProperty("os.version", mode.equals("desktop") ? "Windows-test" : "Android-test");
        try {
            Object platform = XRPlatform.get();
            if (mode.equals("missing") || mode.equals("duplicate")) throw new AssertionError("Expected explicit bridge failure");
            String expected = mode.equals("desktop") ? "$Desktop" : "$Android";
            if (!platform.getClass().getName().endsWith(expected)) throw new AssertionError(platform.getClass());
            if (platform != XRPlatform.get()) throw new AssertionError("Backend should be reused");
        } catch (IllegalStateException error) {
            String expected = mode.equals("missing") ? "No Android XR bridge" : "Multiple Android XR bridges";
            if ((!mode.equals("missing") && !mode.equals("duplicate")) || !error.getMessage().contains(expected)) throw error;
        }
        System.out.println("PASS bridge discovery: " + mode);
    }
}
