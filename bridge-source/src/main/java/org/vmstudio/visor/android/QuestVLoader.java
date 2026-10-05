package org.vmstudio.visor.android;

public final class QuestVLoader {
    private static String deviceModel;

    static {
        System.loadLibrary("vloader");
    }

    private QuestVLoader() {
    }

    public static native long getEGLDisplay();
    public static native long getEGLContext();
    public static native long getEGLConfig();
    public static native long getDalvikVM();
    public static native long getDalvikActivity();
    public static native void setupAndroid();
    private static native String getDeviceModel();

    public static String deviceModel() {
        if (deviceModel == null) {
            deviceModel = getDeviceModel();
        }
        return deviceModel;
    }

    public static boolean isQuest2() {
        return deviceModel().equalsIgnoreCase("Quest 2");
    }

    public static boolean isQuest3Family() {
        return deviceModel().equalsIgnoreCase("Quest 3")
                || deviceModel().equalsIgnoreCase("Quest 3S");
    }
}
