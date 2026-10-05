package org.vmstudio.visor.android;

import me.phoenixra.atumvr.core.session.platform.AndroidXRBridge;

public final class QuestAndroidXRBridge implements AndroidXRBridge {
    @Override
    public long getEGLDisplay() {
        return QuestVLoader.getEGLDisplay();
    }

    @Override
    public long getEGLContext() {
        return QuestVLoader.getEGLContext();
    }

    @Override
    public long getEGLConfig() {
        return QuestVLoader.getEGLConfig();
    }

    @Override
    public long getDalvikVM() {
        return QuestVLoader.getDalvikVM();
    }

    @Override
    public long getDalvikActivity() {
        return QuestVLoader.getDalvikActivity();
    }

    @Override
    public void setupAndroid() {
        QuestVLoader.setupAndroid();
    }
}
