import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

os.system("mkdir -p plots")
df = pd.read_csv("data/processed.csv")
numeric_cols = df.select_dtypes(include=np.number).columns.tolist()
if "log_price" in numeric_cols: numeric_cols.remove("log_price")

print("Generando histogramas. . .")
for col in numeric_cols + ["log_price"]:
    plt.figure(figsize=(6, 4))
    sns.histplot(df[col].dropna(), bins=30, kde=True)
    plt.title(f"Histograma de {col}")
    plt.xlabel(col)
    plt.ylabel("Frecuencia")
    plt.tight_layout()
    plt.savefig(f"plots/hist_{col}.png")
    print(f"plots/hist_{col}.png guardado. . .")
    plt.close()

print("\nGenerando boxes. . .")
for col in numeric_cols + ["log_price"]:
    plt.figure(figsize=(6, 4))
    sns.boxplot(x=df[col].dropna())
    plt.title(f"Boxplot de {col}")
    plt.xlabel(col)
    plt.tight_layout()
    plt.savefig(f"plots/box_{col}.png")
    print(f"plots/box_{col}.png guardado. . .")
    plt.close()

print("\nGenerando scatters. . .")
for col in numeric_cols:
    plt.figure(figsize=(6, 4))
    sns.scatterplot(x=df[col], y=df["log_price"])
    plt.title(f"{col} vs log_price")
    plt.xlabel(col)
    plt.ylabel("log_price")
    plt.tight_layout()
    plt.savefig(f"plots/scatter_{col}_log_price.png")
    print(f"plots/scatter_{col}_log_price.png guardado. . .")
    plt.close()

plt.figure(figsize=(12, 10))
corr_matrix = df[numeric_cols + ["log_price"]].corr()
sns.heatmap(corr_matrix, annot=True, fmt=".2f", cmap="coolwarm", cbar=True)
plt.title("Mapa de calor de correlaciones")
plt.tight_layout()
plt.savefig("plots/corr_heatmap.png")
plt.close()