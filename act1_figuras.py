"""Actividad 1 - Mejora de imagen: operaciones elementales (Vision Artificial).

Reproduccion en Python del procesamiento de act1_mejora_imagen.m, usada para
calcular el ruido estimado, los controles de la imagen 1779 y todas las
figuras del informe.

Las funciones de MATLAB que no existen en Python (rgb2gray, stretchlim,
imadjust, histeq, adapthisteq, ssim) se reimplementan siguiendo el algoritmo
de MATLAB. La reimplementacion reproduce las metricas obtenidas en MATLAB
(media, desviacion, entropia, niveles, saturacion, SNR y SSIM) para la
ecualizacion global, los cuatro limites de CLAHE y la combinacion lineal de
la imagen 1585.

Uso:  python act1_figuras.py   (imagenes en images/, salida en figuras/)
"""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker
from matplotlib.patches import Rectangle
from PIL import Image
from scipy.ndimage import convolve, gaussian_filter

CARPETA_IMG, CARPETA_FIG = "images", "figuras"
os.makedirs(CARPETA_FIG, exist_ok=True)
plt.rcParams.update({"font.size": 7, "axes.titlesize": 7, "axes.labelsize": 7,
                     "xtick.labelsize": 6, "ytick.labelsize": 6,
                     "legend.fontsize": 6, "savefig.dpi": 300})
ANCHO = 6.3  # ancho de texto del informe en pulgadas (16 cm)


# ----------------------------------------------------------------------------
# Equivalentes de las funciones de MATLAB
# ----------------------------------------------------------------------------
def cargar_gris(ruta):
    """rgb2gray (BT.601, redondeo a uint8) + im2double."""
    X = np.asarray(Image.open(ruta).convert("RGB")).astype(float)
    Y = 0.2989 * X[..., 0] + 0.5870 * X[..., 1] + 0.1140 * X[..., 2]
    return np.round(Y).clip(0, 255) / 255


def bins(I, nb=256):
    """Indice de bin de imhist para una imagen double en [0, 1]."""
    return np.floor(np.clip(I, 0, 1) * (nb - 1) + 0.5).astype(int)


def percentil(X, q):
    v = np.sort(X.ravel())
    return v[max(0, int(round(q / 100 * v.size)) - 1)]


def stretchlim(I, bajo, alto):
    cdf = np.cumsum(np.bincount(bins(I).ravel(), minlength=256)) / I.size
    return np.argmax(cdf > bajo) / 255, np.argmax(cdf >= alto) / 255


def imadjust(I, lo, hi):
    return np.clip((I - lo) / (hi - lo), 0, 1)


def histeq(a, n=256):
    """Ecualizacion global con histograma objetivo plano (algoritmo de histeq)."""
    m, N = 256, a.size
    nn = np.bincount(bins(a).ravel(), minlength=m).astype(float)
    cum = np.cumsum(nn)
    cumd = np.cumsum(np.ones(n) * N / n)
    tol = np.minimum(np.r_[nn[:m - 1], 0], np.r_[0, nn[1:]]) / 2
    err = cumd[:, None] - cum[None, :] + tol[None, :]
    err[err < -N * np.sqrt(np.finfo(float).eps)] = N
    T = np.argmin(err, axis=0) / (n - 1)
    return T[bins(a)], T


def _recortar_hist(h, lim, nb):
    """Recorte del histograma y reparto del exceso (clipHistogram de adapthisteq)."""
    h = h.astype(np.int64).copy()
    exceso = int(np.maximum(h - lim, 0).sum())
    inc = exceso // nb
    sup = lim - inc
    for k in range(nb):
        if h[k] > lim:
            h[k] = lim
        elif h[k] > sup:
            exceso -= lim - h[k]
            h[k] = lim
        else:
            exceso -= inc
            h[k] += inc
    k = 0
    while exceso != 0:
        paso = max(nb // exceso, 1)
        for m in range(k, nb, paso):
            if h[m] < lim:
                h[m] += 1
                exceso -= 1
                if exceso == 0:
                    break
        k = (k + 1) % nb
    return h


def adapthisteq(I, clip=0.01, tiles=(8, 8), nb=256):
    """CLAHE con distribucion uniforme e interpolacion bilineal (adapthisteq)."""
    H0, W0 = I.shape

    def relleno(dim, n):  # bloques de tamano par, como en MATLAB
        td, p = (dim // n, 0) if dim % n == 0 else (dim // n + 1, (dim // n + 1) * n - dim)
        return p + (n if td % 2 else 0)

    pr, pc = relleno(H0, tiles[0]), relleno(W0, tiles[1])
    J = np.pad(I, ((pr // 2, pr - pr // 2), (pc // 2, pc - pc // 2)), mode="symmetric")
    H, W = J.shape
    th, tw = H // tiles[0], W // tiles[1]
    N = th * tw
    nmin = int(np.ceil(N / nb))
    lim = nmin + int(np.round(clip * (N - nmin)))
    B = bins(J, nb)
    mapas = np.zeros((tiles[0], tiles[1], nb))
    for r in range(tiles[0]):
        for c in range(tiles[1]):
            h = np.bincount(B[r*th:(r+1)*th, c*tw:(c+1)*tw].ravel(), minlength=nb)
            mapas[r, c] = np.minimum(np.cumsum(_recortar_hist(h, lim, nb)) / N, 1)
    out = np.zeros((H, W))
    r0 = 0
    for k in range(tiles[0] + 1):
        nr, mr = (th // 2, (0, 0)) if k == 0 else \
                 (th // 2, (tiles[0] - 1,) * 2) if k == tiles[0] else (th, (k - 1, k))
        c0 = 0
        for l in range(tiles[1] + 1):
            nc, mc = (tw // 2, (0, 0)) if l == 0 else \
                     (tw // 2, (tiles[1] - 1,) * 2) if l == tiles[1] else (tw, (l - 1, l))
            b = B[r0:r0+nr, c0:c0+nc]
            rw, rrw = np.arange(nr)[:, None], np.arange(nr, 0, -1)[:, None]
            cw, crw = np.arange(nc)[None, :], np.arange(nc, 0, -1)[None, :]
            ul, ur = mapas[mr[0], mc[0]][b], mapas[mr[0], mc[1]][b]
            bl, br = mapas[mr[1], mc[0]][b], mapas[mr[1], mc[1]][b]
            out[r0:r0+nr, c0:c0+nc] = (rrw * (crw * ul + cw * ur) + rw * (crw * bl + cw * br)) / (nr * nc)
            c0 += nc
        r0 += nr
    return out[pr // 2:pr // 2 + H0, pc // 2:pc // 2 + W0]


def sigmoide(r, K, e):
    with np.errstate(divide="ignore"):
        return 1 / (1 + (K / r) ** e)


def realce_laplaciano(X, c):
    h = np.array([[0, 1, 0], [1, -4, 1], [0, 1, 0]], float)
    return np.clip(X - c * convolve(X, h, mode="nearest"), 0, 1)


# ----------------------------------------------------------------------------
# Metricas
# ----------------------------------------------------------------------------
def q8(I):
    return np.round(np.clip(I, 0, 1) * 255)


def entropia(I):
    h = np.bincount(q8(I).astype(int).ravel(), minlength=256) / I.size
    h = h[h > 0]
    return -(h * np.log2(h)).sum()


def ssim(A, R):
    """SSIM con ventana gaussiana (sigma 1,5; 11x11) y bordes replicados."""
    kw = dict(sigma=1.5, truncate=5 / 1.5, mode="nearest")
    C1, C2 = 0.01 ** 2, 0.03 ** 2
    mx, my = gaussian_filter(A, **kw), gaussian_filter(R, **kw)
    sx = gaussian_filter(A * A, **kw) - mx * mx
    sy = gaussian_filter(R * R, **kw) - my * my
    sxy = gaussian_filter(A * R, **kw) - mx * my
    return (((2*mx*my + C1) * (2*sxy + C2)) / ((mx*mx + my*my + C1) * (sx + sy + C2))).mean()


def snr_db(I0, I):
    return 10 * np.log10((I0 ** 2).sum() / (((I - I0) ** 2).sum() + np.finfo(float).eps))


def ruido_immerkaer(I):
    """Desviacion tipica del ruido (Immerkaer, 1996), en niveles 0-255."""
    N = np.array([[1, -2, 1], [-2, 4, -2], [1, -2, 1]], float)
    H, W = I.shape
    C = convolve(I, N)[1:-1, 1:-1]
    return 255 * np.sqrt(np.pi / 2) * np.abs(C).sum() / (6 * (W - 2) * (H - 2))


def metricas(I0, I):
    u = q8(I)
    return dict(media=I.mean(), desv=I.std(ddof=1), H=entropia(I), niveles=len(np.unique(u)),
                pB=100 * (u >= 250).mean(), pN=100 * (u <= 5).mean(),
                snr=snr_db(I0, I), ssim=ssim(I, I0), ruido=ruido_immerkaer(I))


# ----------------------------------------------------------------------------
# Figuras
# ----------------------------------------------------------------------------
def histograma(ax, I, etiqueta_y):
    h = np.bincount(bins(I).ravel(), minlength=256) / I.size
    x = np.arange(256) / 255
    nz = h > 0
    ax.vlines(x[nz], 1e-6, h[nz], color="k", linewidth=0.5)
    ax.set_yscale("log")
    ax.set_xlim(0, 1)
    ax.set_ylim(1e-6, 1)
    ax.set_xticks([0, 0.5, 1])
    ax.set_xticklabels(["0", "0,5", "1"])
    ax.get_xticklabels()[0].set_horizontalalignment("left")
    ax.get_xticklabels()[-1].set_horizontalalignment("right")
    ax.set_yticks([1e-6, 1e-3, 1])
    ax.set_xlabel("Intensidad", labelpad=1)
    if etiqueta_y:
        ax.set_ylabel("Frec. relativa", labelpad=1)
    else:
        ax.set_yticklabels([])
    ax.tick_params(length=2, pad=1)


def fig_comparativa(imgs, titulos, nombre, ancho=ANCHO):
    n = len(imgs)
    alto_img = ancho / n * 720 / 1080
    fig, axs = plt.subplots(2, n, figsize=(ancho, alto_img + 0.95),
                            gridspec_kw=dict(height_ratios=[alto_img, 0.75]))
    axs = np.atleast_2d(axs).reshape(2, n)
    for i, (I, t) in enumerate(zip(imgs, titulos)):
        axs[0, i].imshow(I, cmap="gray", vmin=0, vmax=1, interpolation="lanczos")
        axs[0, i].set_title(t, pad=2)
        axs[0, i].axis("off")
        histograma(axs[1, i], I, i == 0)
    fig.subplots_adjust(left=0.07, right=0.99, top=0.95, bottom=0.12, wspace=0.08, hspace=0.18)
    fig.savefig(os.path.join(CARPETA_FIG, nombre + ".png"), bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)


def recortar(X, rect):  # rect = [x y ancho alto] en coordenadas de MATLAB (desde 1)
    x, y, w, h = rect
    return X[y - 1:y - 1 + h, x - 1:x - 1 + w]


def fig_detalle(f, recortes, titulos, rect, nombre):
    n = len(recortes) + 1
    fig, axs = plt.subplots(1, n, figsize=(ANCHO, ANCHO / n * 0.72 + 0.2))
    axs[0].imshow(f, cmap="gray", vmin=0, vmax=1)
    x, y, w, h = rect
    axs[0].add_patch(Rectangle((x - 1.5, y - 1.5), w, h, fill=False, ec="r", lw=1))
    axs[0].set_title("Zona ampliada", pad=2)
    for ax, R, t in zip(axs[1:], recortes, titulos):
        ax.imshow(R, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
        ax.set_title(t, pad=2)
    for ax in axs:
        ax.axis("off")
    fig.subplots_adjust(left=0.005, right=0.995, top=0.86, bottom=0.01, wspace=0.04)
    fig.savefig(os.path.join(CARPETA_FIG, nombre + ".png"), bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)


def fig_curvas(r, curvas, leyendas, titulo, nombre):
    fig, ax = plt.subplots(figsize=(2.9, 2.6))
    for s, l in zip(curvas, leyendas):
        ax.plot(r, s, lw=1.3, label=l)
    ax.plot([0, r.max()], [0, r.max()], "k--", lw=0.8, label="Identidad $s = r$")
    ax.set_xlim(0, r.max())
    ax.set_ylim(0, 1)
    ax.set_xlabel("Intensidad de entrada $r$")
    ax.set_ylabel("Intensidad de salida $s$")
    ax.set_title(titulo)
    ax.grid(alpha=0.3)
    ax.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: ("%g" % v).replace(".", ",")))
    ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: ("%g" % v).replace(".", ",")))
    ax.legend(loc="lower right")
    fig.tight_layout(pad=0.3)
    fig.savefig(os.path.join(CARPETA_FIG, nombre + ".png"))
    plt.close(fig)


# ----------------------------------------------------------------------------
# Procesamiento (mismos pasos y parametros que act1_mejora_imagen.m)
# ----------------------------------------------------------------------------
ids = ["1779", "1158", "1585", "1830"]
I = {i: cargar_gris(os.path.join(CARPETA_IMG, i + ".png")) for i in ids}
filas = []


def anadir(img, metodo, I0, X):
    filas.append((img, metodo, metricas(I0, X)))


fig_comparativa([I[i] for i in ids], ["Original " + i for i in ids], "fig00_originales")

# 1779
f = I["1779"]
k = 1 / percentil(f, 99.5)
A_1779 = np.minimum(f * k, 1)
lo, hi = stretchlim(f ** 0.5, 0.01, 0.995)
B_1779 = imadjust(f ** 0.5, lo, hi)
EQ_1779 = histeq(f)[0]
CL_1779 = {c: adapthisteq(f, c) for c in [0.02, 0.1, 0.3, 1]}
anadir("1779", "Multiplicacion k=%.1f" % k, f, A_1779)
anadir("1779", "Gamma 0,5 -> estiramiento", f, B_1779)
anadir("1779", "Ecualizacion global", f, EQ_1779)
for c, X in CL_1779.items():
    anadir("1779", "CLAHE beta=%g" % c, f, X)
fig_comparativa([f, A_1779, B_1779], ["Original 1779", r"A) $\times$%.1f" % k,
                 r"B) $\gamma$ = 0,5 + estiramiento"], "fig01_1779_comparativa", ANCHO * 0.75)
fig_comparativa([EQ_1779, CL_1779[0.02], CL_1779[1]],
                ["Ecualización global", r"CLAHE ($\beta$ = 0,02)", r"CLAHE ($\beta$ = 1)"],
                "fig11_1779_histograma", ANCHO * 0.75)
r = np.linspace(0, 0.06, 500)
fig_curvas(r, [np.minimum(k * r, 1), imadjust(r ** 0.5, lo, hi)],
           ["A) multiplicación", "B) gamma + estiramiento"],
           "Imagen 1779", "fig02_1779_curvas")

# 1158
f = I["1158"]
L = np.log(1 + f)
LOG01 = (L - L.min()) / (L.max() - L.min())
LOG = np.log(1 + 255 * f) / np.log(256)
GAM = f ** 0.3
lo, hi = stretchlim(f ** 0.5, 0.01, 0.99)
FIN_1158 = imadjust(f ** 0.5, lo, hi)
for nombre_m, X in [("Log [0,1]", LOG01), ("Log [0,255]", LOG), ("Gamma 0,3", GAM),
                    ("Gamma 0,5 -> estiramiento", FIN_1158)]:
    anadir("1158", nombre_m, f, X)
fig_comparativa([f, LOG01, LOG, GAM, FIN_1158],
                ["Original 1158", "Log en [0, 1]", "Log en [0, 255]", r"$\gamma$ = 0,3",
                 r"$\gamma$ = 0,5 + estir."], "fig03_1158_comparativa")
r = np.linspace(0, 1, 500)
fig_curvas(r, [np.log(1 + r) / np.log(2), np.log(1 + 255 * r) / np.log(256), r ** 0.3, r ** 0.5],
           [r"$\log(1+r)$ en [0, 1]", r"$\log(1+255r)/\log 256$", r"$\gamma$ = 0,3", r"$\gamma$ = 0,5"],
           "Imagen 1158", "fig04_1158_curvas")

# 1585
f = I["1585"]
EQ, Teq = histeq(f)
CL = adapthisteq(f, 0.02)
MIX = 0.3 * EQ + 0.7 * f
for nombre_m, X in [("Ecualizacion global", EQ), ("CLAHE beta=0,02", CL), ("Mezcla alfa=0,3", MIX)]:
    anadir("1585", nombre_m, f, X)
fig_comparativa([f, EQ, CL, MIX], ["Original 1585", "Ecualización global",
                 r"CLAHE ($\beta$ = 0,02)", r"Mezcla ($\alpha$ = 0,3)"], "fig05_1585_comparativa")
rect = [170, 180, 340, 220]
fig_detalle(f, [recortar(X, rect) for X in [f, EQ, CL, MIX]],
            ["Original", "Ecualiz. global", "CLAHE", "Mezcla"], rect, "fig06_1585_detalle_letreros")
fig_curvas(np.arange(256) / 255, [Teq], ["Ecualización global"], "Imagen 1585",
           "fig07_1585_curva_ecualizacion")

# 1830
f = I["1830"]
SIG = sigmoide(f, 0.15, 1.5)
A = realce_laplaciano(SIG, 1.0)
B = sigmoide(realce_laplaciano(f, 1.0), 0.15, 1.5)
FIN = realce_laplaciano(SIG, 0.5)
for nombre_m, X in [("Sigmoide", SIG), ("A) sigm -> lapl c=1", A), ("B) lapl c=1 -> sigm", B),
                    ("Sigm -> lapl c=0,5", FIN)]:
    anadir("1830", nombre_m, f, X)
fig_comparativa([f, SIG, A, B, FIN], ["Original 1830", "Sigmoide", r"A) sigm. $\rightarrow$ lapl.",
                 r"B) lapl. $\rightarrow$ sigm.", "Final ($c$ = 0,5)"], "fig08_1830_comparativa")
rect = [520, 150, 360, 240]
D = recortar(np.abs(A - B), rect)
fig_detalle(f, [recortar(SIG, rect), recortar(A, rect), recortar(B, rect), D / D.max()],
            ["Sigmoide", r"A) sigm. $\rightarrow$ lapl.", r"B) lapl. $\rightarrow$ sigm.", "|A - B|"],
            rect, "fig09_1830_orden_operaciones")
r = np.linspace(0, 1, 500)
fig_curvas(r, [sigmoide(r, 0.12, 1.5), sigmoide(r, 0.15, 1.5), sigmoide(r, 0.20, 1.5),
               sigmoide(r, 0.15, 1)],
           ["K = 0,12, e = 1,5", "K = 0,15, e = 1,5", "K = 0,20, e = 1,5", "K = 0,15, e = 1"],
           "Imagen 1830", "fig10_1830_curvas")

# Tabla de metricas
print("%-5s %-28s %6s %6s %5s %4s %5s %5s %6s %6s %6s" %
      ("Img", "Metodo", "Media", "Desv", "H", "Niv", "%B", "%N", "SNR", "SSIM", "Ruido"))
for img, met, m in filas:
    print("%-5s %-28s %6.3f %6.3f %5.2f %4d %5.2f %5.1f %6.1f %6.3f %6.2f" %
          (img, met, m["media"], m["desv"], m["H"], m["niveles"], m["pB"], m["pN"],
           m["snr"], m["ssim"], m["ruido"]))
