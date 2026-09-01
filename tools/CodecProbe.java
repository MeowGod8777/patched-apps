import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;

public final class CodecProbe {
    private static String profileName(int p) {
        if (p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain8) return "AV1ProfileMain8";
        if (p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10) return "AV1ProfileMain10";
        if (p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10) return "AV1ProfileMain10HDR10";
        if (p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus) return "AV1ProfileMain10HDR10Plus";
        return "UNKNOWN";
    }

    private static MediaFormat av1Format(int profile, boolean hdr) {
        MediaFormat f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AV1, 720, 1280);
        f.setInteger(MediaFormat.KEY_FRAME_RATE, 60);
        f.setInteger(MediaFormat.KEY_PROFILE, profile);
        if (hdr) {
            f.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT2020);
            f.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED);
            f.setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_ST2084);
        }
        return f;
    }

    public static void main(String[] args) {
        System.out.println("=== CodecProbe: Android MediaCodecInfo AV1 runtime capability ===");
        System.out.println("Profiles: Main8=1 Main10=2 HDR10=4096 HDR10Plus=8192");

        MediaCodecList list = new MediaCodecList(MediaCodecList.ALL_CODECS);
        int matched = 0;
        for (MediaCodecInfo info : list.getCodecInfos()) {
            if (info.isEncoder()) continue;
            boolean hasAv1 = false;
            for (String type : info.getSupportedTypes()) {
                if (MediaFormat.MIMETYPE_VIDEO_AV1.equalsIgnoreCase(type)) {
                    hasAv1 = true;
                    break;
                }
            }
            if (!hasAv1) continue;
            matched++;
            System.out.println();
            System.out.println("CODEC=" + info.getName());
            System.out.println("canonical=" + info.getCanonicalName());
            System.out.println("hardwareAccelerated=" + info.isHardwareAccelerated());
            System.out.println("softwareOnly=" + info.isSoftwareOnly());
            System.out.println("vendor=" + info.isVendor());
            try {
                MediaCodecInfo.CodecCapabilities caps = info.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AV1);
                System.out.println("profileLevels.count=" + caps.profileLevels.length);
                for (MediaCodecInfo.CodecProfileLevel pl : caps.profileLevels) {
                    System.out.println("  profile=" + pl.profile + " (" + profileName(pl.profile) + ") level=" + pl.level);
                }
                System.out.print("colorFormats=");
                for (int i = 0; i < caps.colorFormats.length; i++) {
                    if (i != 0) System.out.print(",");
                    System.out.print(caps.colorFormats[i]);
                }
                System.out.println();

                int[] profiles = {
                    MediaCodecInfo.CodecProfileLevel.AV1ProfileMain8,
                    MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10,
                    MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10,
                    MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus
                };
                for (int p : profiles) {
                    boolean hdr = (p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10 ||
                                   p == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus);
                    MediaFormat f = av1Format(p, hdr);
                    try {
                        System.out.println("isFormatSupported profile=" + p + " (" + profileName(p) + ") hdr=" + hdr + " => " + caps.isFormatSupported(f));
                    } catch (Throwable t) {
                        System.out.println("isFormatSupported profile=" + p + " => ERROR " + t);
                    }
                }
            } catch (Throwable t) {
                System.out.println("CAPS_ERROR=" + t);
            }
        }

        System.out.println();
        System.out.println("matchedAv1Decoders=" + matched);
        int[] profiles = {1, 2, 4096, 8192};
        for (int p : profiles) {
            boolean hdr = (p == 4096 || p == 8192);
            try {
                String decoder = list.findDecoderForFormat(av1Format(p, hdr));
                System.out.println("findDecoderForFormat profile=" + p + " (" + profileName(p) + ") hdr=" + hdr + " => " + decoder);
            } catch (Throwable t) {
                System.out.println("findDecoderForFormat profile=" + p + " => ERROR " + t);
            }
        }
    }
}
