%% Actividad 1 – Mejora de imagen: operaciones elementales
% Visión Artificial · Máster en Inteligencia Artificial
%
% Se mejoran cuatro imágenes nocturnas de la base de datos DARK FACE
% (Yang et al., 2020), trabajando en escala de grises. Cada imagen recibe
% un procesamiento distinto, elegido según su problema concreto, y se
% combinan las tres familias de técnicas del tema 6:
%
% * Transformaciones de intensidad: multiplicación por constante, gamma,
%   logarítmica, estiramiento lineal y estiramiento no lineal (sigmoide).
% * Procesamiento del histograma: ecualización global y adaptativa (CLAHE),
%   aplicadas a la imagen 1585 (y como control a la 1779).
% * Operaciones aritméticas: multiplicación por constante, combinación
%   lineal de imágenes y realce por resta del laplaciano.
%
% Estructura de carpetas esperada (junto a este script):
%
%   images/1779.png, images/1158.png, images/1585.png, images/1830.png
%
% El script crea la carpeta resultados/ con todas las figuras
% (PNG a 150 ppp) y el archivo metricas.xlsx (hoja "Resultados" y hoja "Barridos").

clear; close all; clc;

carpetaImg = 'images';
carpetaOut = 'resultados';

% En MATLAB Online la exportación de figuras puede fallar o bloquearse.
% Con false, las figuras solo se muestran en pantalla; las imágenes
% procesadas y las métricas se guardan igualmente. En MATLAB de
% escritorio se puede poner true para exportar también las figuras.
exportarFiguras = false;
setappdata(groot, 'exportarFiguras', exportarFiguras);
[~, ~] = mkdir(carpetaOut);   % se crea siempre (si ya existe, no pasa nada)
assert(isfolder(carpetaOut), 'No se ha podido crear la carpeta "%s"', carpetaOut);

ids = {'1779', '1158', '1585', '1830'};   % de más oscura a más iluminada

T  = table();   % métricas de los resultados principales
Tb = table();   % métricas de los barridos de parámetros (anexo)

%% 0. Material: características de las imágenes originales
% Se leen las imágenes en color, se comprueban sus características
% (resolución, profundidad de bits) y se convierten a escala de grises con
% la ponderación de luminancia de la recomendación ITU-R BT.601:
%
% $$Y = 0.2989\,R + 0.5870\,G + 0.1140\,B$$
%
% A continuación se pasan a tipo double en el rango [0, 1] para operar
% sin desbordamientos.

I = struct();
for k = 1:numel(ids)
    ruta = fullfile(carpetaImg, [ids{k} '.png']);
    info = imfinfo(ruta);
    fprintf('%s.png: %d x %d px, %d bits/píxel, tipo de color: %s\n', ...
        ids{k}, info.Width, info.Height, info.BitDepth, info.ColorType);
    I.(['im' ids{k}]) = cargar_gris(ruta);
end

% Figura de las cuatro originales en gris con sus histogramas
originales = cellfun(@(id) I.(['im' id]), ids, 'UniformOutput', false);
fig = fig_comparativa(originales, strcat({'Original '}, ids));
guardar(fig, carpetaOut, 'fig00_originales');
progreso('Sección 0 (originales) terminada');

for k = 1:numel(ids)
    Ik = I.(['im' ids{k}]);
    T = anadir_fila(T, ids{k}, "Original", Ik, Ik);
end
disp(T)

%% 1. Imagen 1779: caso límite (prácticamente negra)
% El 99,5 % de los píxeles tiene un nivel de gris menor o igual que 6 (de
% 255). La información útil se concentra en muy pocos niveles, así que se
% espera que ninguna transformación pueda recuperar detalle sin generar
% bandas (posterización) y ruido. Se comparan:
%
% * *A) Operación aritmética:* multiplicación por una constante
%   $g = \min(k \cdot f,\, 1)$, con $k = 1/P_{99.5}(f)$, de modo que el
%   percentil 99,5 pase a blanco.
% * *B) Gamma seguida de estiramiento lineal:* $g = \mathrm{estirar}(f^{\gamma})$
%   con saturación del 1 % inferior y del 0,5 % superior.
% * *Control:* ecualización global y CLAHE con varios límites de contraste,
%   para comprobar si una técnica de histograma supera a las anteriores.

f = I.im1779;

% --- A) Multiplicación por constante (barrido + valor elegido)
for kb = [10 20 40]
    Tb = anadir_fila(Tb, '1779', sprintf("Multiplicación k=%d", kb), f, min(f*kb, 1));
end
k_1779 = 1 / percentil(f, 99.5);
A_1779 = min(f * k_1779, 1);
fprintf('1779: k elegido = 1/P99.5 = %.1f\n', k_1779);

% --- B) Gamma -> estiramiento (barrido + valor elegido)
for g = [0.4 0.5 0.6]
    Ig  = f.^g;
    lim = stretchlim(Ig, [0.01 0.995]);
    Tb  = anadir_fila(Tb, '1779', sprintf("Gamma=%.1f -> estiramiento", g), f, imadjust(Ig, lim, []));
end
gamma_1779 = 0.5;
Ig       = f.^gamma_1779;
lim_1779 = stretchlim(Ig, [0.01 0.995]);
B_1779   = imadjust(Ig, lim_1779, []);

% --- Control: técnicas de histograma sobre la imagen casi negra
EQ_1779 = histeq(f, 256);
Tb = anadir_fila(Tb, '1779', "Ecualización global", f, EQ_1779);
for c = [0.02 0.1 0.3 1]
    Tb = anadir_fila(Tb, '1779', sprintf("CLAHE clip=%.2f", c), f, ...
        adapthisteq(f, 'ClipLimit', c, 'NumTiles', [8 8]));
end
CLAHE_1779 = adapthisteq(f, 'ClipLimit', 0.02, 'NumTiles', [8 8]);

T = anadir_fila(T, '1779', sprintf("Multiplicación k=%.1f", k_1779), f, A_1779);
T = anadir_fila(T, '1779', sprintf("Gamma=%.1f -> estiramiento", gamma_1779), f, B_1779);

fig = fig_comparativa({f, A_1779, B_1779}, ...
    {'Original 1779', sprintf('A) \\times%.1f', k_1779), sprintf('B) \\gamma=%.1f + estiramiento', gamma_1779)});
guardar(fig, carpetaOut, 'fig01_1779_comparativa');

% Curvas de transformación en la zona de intensidades donde está la imagen
r  = linspace(0, 0.06, 500);
sA = min(k_1779 * r, 1);
sB = min(max((r.^gamma_1779 - lim_1779(1)) / (lim_1779(2) - lim_1779(1)), 0), 1);
fig = fig_curvas(r, {sA, sB}, {'A) multiplicación', 'B) gamma + estiramiento'}, ...
    'Imagen 1779: funciones de transformación');
guardar(fig, carpetaOut, 'fig02_1779_curvas');

fprintf('1779: niveles de gris distintos -> original %d, A %d, B %d\n', ...
    niveles(f), niveles(A_1779), niveles(B_1779));
progreso('Sección 1 (imagen 1779) terminada');

%% 2. Imagen 1158: muy oscura, pero con información en las sombras
% El brillo medio es 0,017, aunque la imagen ocupa los 256 niveles: hay
% detalle oculto en las sombras. Se comparan dos curvas que expanden los
% oscuros:
%
% * *Logarítmica.* Normalizada al rango [0, 1], $\log(1+r)$ es casi una
%   recta y apenas cambia la imagen. Por eso se usa la forma equivalente a
%   operar en [0, 255]: $s = \log(1 + 255\,r)/\log(256)$.
% * *Gamma* con $\gamma < 1$ (barrido de $\gamma$).
%
% Por último se combina gamma 0,5 con un estiramiento lineal (saturación
% del 1 %), para ver si así se gana contraste. Con límite inferior 0, gamma
% y estiramiento conmutan:
% $(r/h)^{\gamma} = r^{\gamma}/h^{\gamma}$. Se comprueba numéricamente.

f = I.im1158;

% --- Logarítmica: versión en [0,1] (c = 1) frente a versión en [0,255]
Llog01     = log(1 + f);
LOG01_1158 = (Llog01 - min(Llog01(:))) / (max(Llog01(:)) - min(Llog01(:)));
LOG_1158   = log(1 + 255*f) / log(256);

% --- Gamma: barrido
for g = [0.3 0.4 0.5 0.6]
    Tb = anadir_fila(Tb, '1158', sprintf("Gamma=%.1f", g), f, f.^g);
end
GAM_1158 = f.^0.3;   % brillo medio comparable al de la logarítmica

% --- Combinación gamma -> estiramiento lineal
gamma_1158 = 0.5;
Ig         = f.^gamma_1158;
lim_1158   = stretchlim(Ig, [0.01 0.99]);
FIN_1158   = imadjust(Ig, lim_1158, []);

% Comprobación de la conmutatividad (estiramiento -> gamma)
lim0   = stretchlim(f, [0.01 0.99]);
ALT    = imadjust(f, lim0, []).^gamma_1158;
fprintf('1158: diferencia media |gamma->estir - estir->gamma| = %.4f\n', mean(abs(FIN_1158(:) - ALT(:))));

T = anadir_fila(T, '1158', "Logarítmica c=1 en [0,1]", f, LOG01_1158);
T = anadir_fila(T, '1158', "Logarítmica en [0,255]", f, LOG_1158);
T = anadir_fila(T, '1158', "Gamma=0.3", f, GAM_1158);
T = anadir_fila(T, '1158', sprintf("Gamma=%.1f -> estiramiento", gamma_1158), f, FIN_1158);

fig = fig_comparativa({f, LOG01_1158, LOG_1158, GAM_1158, FIN_1158}, ...
    {'Original 1158', 'Log en [0,1]', 'Log en [0,255]', '\gamma = 0.3', '\gamma = 0.5 + estiramiento'});
guardar(fig, carpetaOut, 'fig03_1158_comparativa');

r = linspace(0, 1, 500);
fig = fig_curvas(r, {log(1+r)/log(2), log(1+255*r)/log(256), r.^0.3, r.^0.5}, ...
    {'log(1+r) en [0,1]', 'log(1+255r)/log 256', '\gamma = 0.3', '\gamma = 0.5'}, ...
    'Imagen 1158: transformaciones logarítmica y gamma');
guardar(fig, carpetaOut, 'fig04_1158_curvas');
progreso('Sección 2 (imagen 1158) terminada');

%% 3. Imagen 1585: oscura con letreros luminosos (alto rango dinámico)
% Casi la mitad de los píxeles son negros, pero los letreros ya están
% cerca de la saturación. Es la única imagen en la que se usa la
% ecualización del histograma:
%
% * *Ecualización global:* $s_k = \sum_{j=0}^{k} p_r(r_j)$. Es una única
%   curva para toda la imagen.
% * *CLAHE:* ecualización por bloques de 8x8 con límite de contraste
%   (barrido del límite).
% * *Combinación lineal (aritmética):* $g = \alpha\,E + (1-\alpha)\,f$, que
%   mezcla la imagen ecualizada $E$ con la original para atenuar sus
%   artefactos.

f = I.im1585;

% --- Ecualización global (256 niveles) y su función de transformación
[EQ_1585, Teq] = histeq(f, 256);

% --- CLAHE: barrido del límite de contraste
for c = [0.005 0.01 0.02 0.04]
    Tb = anadir_fila(Tb, '1585', sprintf("CLAHE clip=%.3f", c), f, ...
        adapthisteq(f, 'ClipLimit', c, 'NumTiles', [8 8]));
end
clip_1585  = 0.02;
CLAHE_1585 = adapthisteq(f, 'ClipLimit', clip_1585, 'NumTiles', [8 8]);

% --- Combinación lineal: barrido de alfa
for a = [0.3 0.5 0.7]
    Tb = anadir_fila(Tb, '1585', sprintf("Mezcla alfa=%.1f", a), f, imlincomb(a, EQ_1585, 1-a, f));
end
alfa_1585  = 0.3;
MIX_1585   = imlincomb(alfa_1585, EQ_1585, 1-alfa_1585, f);

T = anadir_fila(T, '1585', "Ecualización global", f, EQ_1585);
T = anadir_fila(T, '1585', sprintf("CLAHE clip=%.2f", clip_1585), f, CLAHE_1585);
T = anadir_fila(T, '1585', sprintf("Mezcla alfa=%.1f", alfa_1585), f, MIX_1585);

fig = fig_comparativa({f, EQ_1585, CLAHE_1585, MIX_1585}, ...
    {'Original 1585', 'Ecualización global', sprintf('CLAHE (clip = %.2f)', clip_1585), ...
     sprintf('Mezcla \\alpha = %.1f', alfa_1585)});
guardar(fig, carpetaOut, 'fig05_1585_comparativa');

% Ampliación de la zona de los letreros (zona de saturación). La primera
% imagen marca en rojo la región ampliada en las demás.
rect = [170 180 340 220];   % [x y ancho alto]
recortes = cellfun(@(X) recortar(X, rect), {f, EQ_1585, CLAHE_1585, MIX_1585}, 'UniformOutput', false);
fig = figure('Color', 'w', 'Position', [50 50 1250 300]);
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(tl); imshow(f, [0 1]); title('Zona ampliada');
rectangle('Position', rect, 'EdgeColor', 'r', 'LineWidth', 1.5);
tit = {'Original (detalle)', 'Ecualiz. global (detalle)', 'CLAHE (detalle)', 'Mezcla (detalle)'};
for i = 1:4
    nexttile(tl); imshow(recortes{i}, [0 1]); title(tit{i});
end
guardar(fig, carpetaOut, 'fig06_1585_detalle_letreros');

r = linspace(0, 1, 256);
fig = fig_curvas(r, {Teq(:)'}, {'Ecualización global'}, ...
    'Imagen 1585: función de transformación de la ecualización');
guardar(fig, carpetaOut, 'fig07_1585_curva_ecualizacion');
progreso('Sección 3 (imagen 1585) terminada');

%% 4. Imagen 1830: la mejor iluminada (orden de las operaciones)
% La imagen ya es interpretable, así que se busca una mejora moderada:
%
% * *Estiramiento no lineal (sigmoide):* $s = 1/(1 + (K/r)^{e})$. $K$ es
%   la intensidad que pasa a 0,5. Se elige $K \approx$ brillo medio de la
%   imagen (0,157), es decir, $K = 0{,}15$ y $e = 1{,}5$.
% * *Realce por laplaciano (aritmética):* $g = f - c\,\nabla^2 f$, con el
%   núcleo $[0\ 1\ 0;\ 1\ {-4}\ 1;\ 0\ 1\ 0]$, operando en double para
%   conservar los valores negativos del laplaciano.
%
% Se compara el orden: A) sigmoide -> laplaciano frente a B) laplaciano ->
% sigmoide, con $c = 1$. El resultado final usa el orden A con $c = 0{,}5$.

f = I.im1830;

% --- Sigmoide: barrido de K y e
for K = [0.12 0.15 0.20]
    for e = [1 1.5]
        Tb = anadir_fila(Tb, '1830', sprintf("Sigmoide K=%.2f e=%.1f", K, e), f, sigmoide(f, K, e));
    end
end
K_1830 = 0.15;  e_1830 = 1.5;
SIG_1830 = sigmoide(f, K_1830, e_1830);

% --- Orden de las operaciones
A_1830   = realce_laplaciano(SIG_1830, 1.0);                       % sigmoide -> laplaciano
B_1830   = sigmoide(realce_laplaciano(f, 1.0), K_1830, e_1830);    % laplaciano -> sigmoide
FIN_1830 = realce_laplaciano(SIG_1830, 0.5);                       % resultado final
fprintf('1830: diferencia media |A - B| = %.4f\n', mean(abs(A_1830(:) - B_1830(:))));

T = anadir_fila(T, '1830', sprintf("Sigmoide K=%.2f e=%.1f", K_1830, e_1830), f, SIG_1830);
T = anadir_fila(T, '1830', "Sigmoide -> laplaciano (c=1)", f, A_1830);
T = anadir_fila(T, '1830', "Laplaciano (c=1) -> sigmoide", f, B_1830);
T = anadir_fila(T, '1830', "Sigmoide -> laplaciano (c=0.5)", f, FIN_1830);

fig = fig_comparativa({f, SIG_1830, A_1830, B_1830, FIN_1830}, ...
    {'Original 1830', 'Sigmoide', 'A) sigm. \rightarrow lapl.', 'B) lapl. \rightarrow sigm.', 'Final (c = 0.5)'});
guardar(fig, carpetaOut, 'fig08_1830_comparativa');

% Ampliación y mapa de diferencias entre órdenes. La primera imagen marca
% en rojo la región ampliada en las demás.
rect = [520 150 360 240];   % [x y ancho alto]
fig = figure('Color', 'w', 'Position', [50 50 1250 300]);
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(tl); imshow(f, [0 1]); title('Zona ampliada');
rectangle('Position', rect, 'EdgeColor', 'r', 'LineWidth', 1.5);
nexttile(tl); imshow(recortar(SIG_1830, rect), [0 1]); title('Sigmoide (detalle)');
nexttile(tl); imshow(recortar(A_1830, rect), [0 1]); title('A) sigm. \rightarrow lapl. (detalle)');
nexttile(tl); imshow(recortar(B_1830, rect), [0 1]); title('B) lapl. \rightarrow sigm. (detalle)');
D = recortar(abs(A_1830 - B_1830), rect);
nexttile(tl); imshow(D / max(D(:)), [0 1]);   % gris: negro = 0, blanco = máximo
title('|A - B| (detalle)');
guardar(fig, carpetaOut, 'fig09_1830_orden_operaciones');

r = linspace(0, 1, 500);
fig = fig_curvas(r, {sigmoide(r,0.12,1.5), sigmoide(r,0.15,1.5), sigmoide(r,0.20,1.5), sigmoide(r,0.15,1)}, ...
    {'K=0.12, e=1.5', 'K=0.15, e=1.5', 'K=0.20, e=1.5', 'K=0.15, e=1'}, ...
    'Imagen 1830: estiramiento no lineal (sigmoide)');
guardar(fig, carpetaOut, 'fig10_1830_curvas');
progreso('Sección 4 (imagen 1830) terminada');

%% 5. Guardado de las imágenes procesadas
% Se guardan en PNG (8 bits) las imágenes en gris y todos los resultados
% principales. No requiere dibujar figuras, así que funciona siempre.

resultados = { ...
    'gris_1779', I.im1779;  '1779_A_multiplicacion', A_1779;  '1779_B_gamma_estiramiento', B_1779; ...
    '1779_ecualizacion_global', EQ_1779;  '1779_clahe', CLAHE_1779; ...
    'gris_1158', I.im1158;  '1158_log_01', LOG01_1158;  '1158_log_0_255', LOG_1158; ...
    '1158_gamma_03', GAM_1158;  '1158_final_gamma_estiramiento', FIN_1158; ...
    'gris_1585', I.im1585;  '1585_ecualizacion_global', EQ_1585;  '1585_clahe', CLAHE_1585; ...
    '1585_mezcla', MIX_1585; ...
    'gris_1830', I.im1830;  '1830_sigmoide', SIG_1830;  '1830_A_sigmoide_laplaciano', A_1830; ...
    '1830_B_laplaciano_sigmoide', B_1830;  '1830_final', FIN_1830; ...
    '1830_dif_AB', abs(A_1830 - B_1830) / max(abs(A_1830(:) - B_1830(:)))};
for i = 1:size(resultados, 1)
    imwrite(im2uint8(resultados{i, 2}), fullfile(carpetaOut, [resultados{i, 1} '.png']));
end
progreso('Imágenes procesadas guardadas');

%% 6. Exportación de las métricas
% * *Media:* brillo global.
% * *Desviación típica:* contraste RMS.
% * *Entropía:* información, en bits.
% * *Niveles:* número de niveles de gris distintos.
% * *% blanco / % negro:* píxeles saturados (>= 250 o <= 5 en escala 0–255).
% * *SNR (dB):* $10\log_{10}\left(\sum f^2 / \sum (g-f)^2\right)$, como en el
%   material del tema 6, tomando como "ruido" la diferencia entre la
%   procesada $g$ y la original $f$.
% * *SSIM:* similitud estructural con la original.
% * *Ruido estimado:* desviación típica del ruido según el método de
%   Immerkær (1996), en niveles de 0 a 255. Se basa en un filtro que anula
%   las zonas de intensidad constante o lineal, de modo que mide la energía
%   de alta frecuencia: tras un realce de bordes incluye también el detalle
%   fino, no solo el ruido.
%
% Ni el SNR ni el SSIM son medidas de calidad, porque no existe una imagen
% de referencia bien iluminada. Indican cuánto se ha alejado el resultado
% de la original: valores bajos significan un cambio grande. Para la
% original, el SNR es muy alto (no hay diferencia) y el SSIM vale 1.

disp(T)
writetable(T,  fullfile(carpetaOut, 'metricas.xlsx'), 'Sheet', 'Resultados');
writetable(Tb, fullfile(carpetaOut, 'metricas.xlsx'), 'Sheet', 'Barridos');
fprintf('Figuras y métricas guardadas en la carpeta "%s".\n', carpetaOut);

%% Funciones auxiliares

function progreso(msg)
% Muestra la hora y el punto del script en el que se está.
    fprintf('[%s] %s\n', char(datetime('now', 'Format', 'HH:mm:ss')), msg);
end

function Ig = cargar_gris(ruta)
% Lee una imagen, la convierte a gris (BT.601) y a double en [0,1].
    X = imread(ruta);
    if size(X, 3) == 3
        X = rgb2gray(X);
    end
    Ig = im2double(X);
end

function p = percentil(X, q)
% Percentil q (0-100) de los valores de X, sin necesidad de toolboxes extra.
    v = sort(X(:));
    p = v(max(1, round(q/100 * numel(v))));
end

function n = niveles(X)
% Número de niveles de gris distintos al representar X en 8 bits.
    n = numel(unique(im2uint8(X)));
end

function s = sigmoide(r, K, e)
% Estiramiento no lineal s = 1 / (1 + (K/r)^e). Para r = 0 devuelve 0.
    s = 1 ./ (1 + (K ./ r).^e);
end

function G = realce_laplaciano(X, c)
% Realce por resta del laplaciano: G = X - c * lap(X), recortado a [0,1].
    h = [0 1 0; 1 -4 1; 0 1 0];
    L = imfilter(double(X), h, 'replicate');
    G = min(max(double(X) - c * L, 0), 1);
end

function snr_val = snr_db(I0, I)
% SNR en dB tal como se define en el material del tema 6: la diferencia
% entre la imagen procesada y la original se trata como "ruido".
    ruido = I - I0;
    snr_val = 10 * log10(sum(I0(:).^2) / (sum(ruido(:).^2) + eps));
end

function s = ruido_immerkaer(X)
% Estimación rápida de la desviación típica del ruido (Immerkær, 1996).
    N = [1 -2 1; -2 4 -2; 1 -2 1];
    C = conv2(double(X), N, 'valid');
    [H, W] = size(X);
    s = sqrt(pi/2) * sum(abs(C(:))) / (6 * (W-2) * (H-2));
end

function T = anadir_fila(T, imagen, metodo, I0, I)
% Calcula las métricas de I (respecto a la original I0) y las añade a T.
    u = im2uint8(I);
    fila = table(string(imagen), string(metodo), ...
        mean(I(:)), std(I(:)), entropy(I), niveles(I), ...
        100 * mean(u(:) >= 250), 100 * mean(u(:) <= 5), ...
        snr_db(I0, I), ssim(I, I0), 255 * ruido_immerkaer(I), ...
        'VariableNames', {'Imagen', 'Metodo', 'Media', 'DesvTipica', 'Entropia', ...
        'Niveles', 'PctBlanco', 'PctNegro', 'SNR_dB', 'SSIM', 'Ruido255'});
    T = [T; fila];
end

function R = recortar(X, rect)
% Recorte [x y ancho alto] en coordenadas de píxel.
    R = X(rect(2):rect(2)+rect(4)-1, rect(1):rect(1)+rect(3)-1);
end

function fig = fig_comparativa(imgs, titulos)
% Fila superior: imágenes. Fila inferior: histogramas normalizados (eje y logarítmico).
    n = numel(imgs);
    fig = figure('Color', 'w', 'Position', [50 50 min(260*n, 1250) 460]);
    tl = tiledlayout(fig, 2, n, 'TileSpacing', 'compact', 'Padding', 'compact');
    x = (0:255) / 255;
    for i = 1:n
        nexttile(tl, i);
        imshow(imgs{i}, [0 1]);
        title(titulos{i});
        nexttile(tl, n + i);
        h = imhist(imgs{i}, 256) / numel(imgs{i});
        nz = h > 0;   % en escala log los ceros no se pueden dibujar
        stem(x(nz), h(nz), 'k', 'Marker', 'none', 'BaseValue', 1e-6, 'ShowBaseLine', 'off');
        set(gca, 'YScale', 'log');
        xlim([0 1]); ylim([1e-6 1]); grid on;
        xlabel('Intensidad');
        if i == 1, ylabel('Frecuencia relativa (log)'); end
    end
end

function fig = fig_curvas(r, curvas, leyendas, titulo)
% Representa una o varias funciones de transformación s = T(r).
    fig = figure('Color', 'w', 'Position', [100 100 520 440]);
    hold on;
    for i = 1:numel(curvas)
        plot(r, curvas{i}, 'LineWidth', 1.8);
    end
    plot([0 max(r)], [0 max(r)], 'k--');
    hold off;
    grid on; axis square;
    xlabel('Intensidad de entrada r'); ylabel('Intensidad de salida s');
    xlim([0 max(r)]); ylim([0 1]);
    title(titulo);
    legend([leyendas, {'Identidad s = r'}], 'Location', 'southeast');
end

function guardar(fig, carpeta, nombre)
% Exporta la figura a PNG con 150 ppp para el informe. Si exportgraphics
% falla (ocurre a veces en MATLAB Online), prueba con print y con saveas.
    if ~getappdata(groot, 'exportarFiguras')
        return;
    end
    archivo = fullfile(pwd, carpeta, [nombre '.png']);
    fprintf('   guardando %s...\n', nombre);
    drawnow;
    try
        exportgraphics(fig, archivo, 'Resolution', 150);
    catch
        try
            print(fig, archivo, '-dpng', '-r150');
        catch
            try
                saveas(fig, archivo);
            catch err
                warning('No se pudo guardar %s: %s', nombre, err.message);
            end
        end
    end
end
