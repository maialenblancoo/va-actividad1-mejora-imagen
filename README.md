# Actividad 1 – Mejora de imagen: operaciones elementales

Visión Artificial · Máster Universitario en Inteligencia Artificial (UNIR)
Autora: Maialen Blanco Ibarra · Noviembre de 2026

Código asociado al informe *Mejora de imágenes nocturnas mediante operaciones elementales: transformaciones de intensidad, procesamiento del histograma y operaciones aritméticas*.

## Contenido

| Archivo | Descripción |
|---|---|
| `act1_mejora_imagen.m` | Script de MATLAB (R2026b + Image Processing Toolbox) con todo el procesamiento y el cálculo de las métricas. Genera `resultados/metricas.xlsx` (hojas *Resultados* y *Barridos*). |
| `act1_figuras.py` | Script de Python 3 (NumPy, SciPy, Matplotlib) que repite el procesamiento solo para dibujar las figuras del informe. Los valores numéricos del informe proceden siempre de MATLAB. |

## Imágenes

Las imágenes no se incluyen en el repositorio. Proceden de la base de datos DARK FACE (Yang et al., 2020), disponible en Kaggle:
https://www.kaggle.com/datasets/soumikrakshit/dark-face-dataset

Descarga los archivos `1779.png`, `1158.png`, `1585.png` y `1830.png` y colócalos así:

```
act1_mejora_imagen.m
act1_figuras.py
images/
  1779.png
  1158.png
  1585.png
  1830.png
```

## Uso

1. **MATLAB:** abre la carpeta y ejecuta `act1_mejora_imagen.m`. Las métricas se guardan en `resultados/metricas.xlsx`. En MATLAB de escritorio puedes poner `exportarFiguras = true` para exportar también las figuras.
2. **Python (opcional, solo figuras):**
   ```
   pip install numpy scipy matplotlib pillow
   python act1_figuras.py
   ```
   Las figuras se guardan en `figuras/`.

## Referencia del conjunto de datos

W. Yang et al., "Advancing image understanding in poor visibility environments: A collective benchmark study," *IEEE Transactions on Image Processing*, vol. 29, pp. 5737–5752, 2020.
