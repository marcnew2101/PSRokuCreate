using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace Roku.Native
{
    public class GradientRenderer
    {
        // Floyd-Steinberg error diffusion. LinearGradientBrush quantizes float
        // colors to 8-bit and discards the rounding error, which is what causes
        // the visible banding on Roku/TV 8-bit display chains. This version
        // keeps the float precision and pushes the rounding error to neighboring
        // pixels (7/16 right, 3/16 below-left, 5/16 below, 1/16 below-right),
        // so the resulting noise pattern follows the gradient direction instead
        // of repeating in a visible grid like Bayer dither would.
        public static void Render(Bitmap bmp,
            int r0, int g0, int b0, int r1, int g1, int b1)
        {
            int width = bmp.Width;
            int height = bmp.Height;
            var rect = new Rectangle(0, 0, width, height);
            var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            int stride = Math.Abs(data.Stride);
            int bufSize = stride * height;
            byte[] buf = new byte[bufSize];

            // Rolling two-row error accumulators with +2 padding to avoid bounds checks.
            float[] curR = new float[width + 2];
            float[] curG = new float[width + 2];
            float[] curB = new float[width + 2];
            float[] nxtR = new float[width + 2];
            float[] nxtG = new float[width + 2];
            float[] nxtB = new float[width + 2];

            float diagLen2 = (float)(width * width + height * height);
            int dr = r1 - r0, dg = g1 - g0, db = b1 - b0;

            for (int y = 0; y < height; y++) {
                int rowOffset = y * stride;
                for (int x = 0; x < width; x++) {
                    // Project (x, y) onto the (width, height) diagonal -> 0..1
                    float t = (x * width + y * height) / diagLen2;

                    float fr = r0 + t * dr + curR[x + 1];
                    float fg = g0 + t * dg + curG[x + 1];
                    float fb = b0 + t * db + curB[x + 1];

                    int qr = (int)Math.Round(fr);
                    int qg = (int)Math.Round(fg);
                    int qb = (int)Math.Round(fb);
                    if (qr < 0) qr = 0; else if (qr > 255) qr = 255;
                    if (qg < 0) qg = 0; else if (qg > 255) qg = 255;
                    if (qb < 0) qb = 0; else if (qb > 255) qb = 255;

                    float er = fr - qr, eg = fg - qg, eb = fb - qb;

                    curR[x + 2] += er * 0.4375f;  // right (7/16)
                    curG[x + 2] += eg * 0.4375f;
                    curB[x + 2] += eb * 0.4375f;
                    nxtR[x]     += er * 0.1875f;  // below-left (3/16)
                    nxtG[x]     += eg * 0.1875f;
                    nxtB[x]     += eb * 0.1875f;
                    nxtR[x + 1] += er * 0.3125f;  // below (5/16)
                    nxtG[x + 1] += eg * 0.3125f;
                    nxtB[x + 1] += eb * 0.3125f;
                    nxtR[x + 2] += er * 0.0625f;  // below-right (1/16)
                    nxtG[x + 2] += eg * 0.0625f;
                    nxtB[x + 2] += eb * 0.0625f;

                    int idx = rowOffset + x * 4;
                    buf[idx + 0] = (byte)qb;
                    buf[idx + 1] = (byte)qg;
                    buf[idx + 2] = (byte)qr;
                    buf[idx + 3] = 255;
                }
                var tmp = curR; curR = nxtR; nxtR = tmp;
                tmp = curG; curG = nxtG; nxtG = tmp;
                tmp = curB; curB = nxtB; nxtB = tmp;
                Array.Clear(nxtR, 0, nxtR.Length);
                Array.Clear(nxtG, 0, nxtG.Length);
                Array.Clear(nxtB, 0, nxtB.Length);
            }

            Marshal.Copy(buf, 0, data.Scan0, bufSize);
            bmp.UnlockBits(data);
        }
    }
}
