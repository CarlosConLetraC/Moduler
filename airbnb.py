import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

os.system("mkdir -p plots")

df = pd.read_csv("data/processed.csv", on_bad_lines='skip')
df = df.apply(pd.to_numeric, errors="coerce")
df = df.dropna(axis=1, how="all")
<<<<<<< HEAD
df.rename(columns=lambda x: x.strip(), inplace=True)# elimina espacios alrededor
=======
df.rename(columns=lambda x: x.strip(), inplace=True)  # elimina espacios alrededor
>>>>>>> 5d6556d7aed047c86b6edece42253bc4c9f47b6f
def is_useful(col): return col.notna().sum() > 50 and col.nunique() > 1

numeric_cols = [col for col in df.columns if pd.api.types.is_numeric_dtype(df[col]) and is_useful(df[col])]

if "log_price" not in df.columns: raise ValueError("log_price no existe en el dataset")
df["log_price"] = pd.to_numeric(df["log_price"], errors="coerce")
cols_for_corr = [c for c in numeric_cols if c != "log_price"] + ["log_price"]
cols_for_corr = [c for c in numeric_cols if c != "log_price"] + ["log_price"]

corr_matrix = df[cols_for_corr].corr()
if "log_price" not in corr_matrix: raise ValueError("log_price no pudo calcular correlación (demasiados NaN)")

corr = corr_matrix["log_price"].dropna()
important_cols = [c for c in corr.index if c != "log_price" and abs(corr[c]) > 0.1]
important_cols = corr[abs(corr) > 0.1].index.tolist()
important_cols = [c for c in important_cols if c != "log_price"]

print("\nGenerando histogramas...")
for col in important_cols + ["log_price"]:
    data = df[col].dropna()
    if len(data) < 50: continue

    plt.figure(figsize=(6, 4))
    sns.histplot(data, bins=30, kde=True)
    plt.title(f"Histograma de {col}")
    plt.xlabel(col)
    plt.ylabel("Frecuencia")
    plt.tight_layout()
    plt.savefig(f"plots/hist_{col}.png")
    print(f"plots/hist_{col}.png guardado")
    plt.close()

print("\nGenerando boxplots...")
for col in important_cols + ["log_price"]:
    data = df[col].dropna()
    if len(data) < 50: continue

    plt.figure(figsize=(6, 4))
    sns.boxplot(x=data)
    plt.title(f"Boxplot de {col}")
    plt.xlabel(col)
    plt.tight_layout()
    plt.savefig(f"plots/box_{col}.png")
    print(f"plots/box_{col}.png guardado")
    plt.close()

print("\nGenerando scatter plots...")
for col in important_cols:
    valid = df[[col, "log_price"]].dropna()

    if len(valid) < 50: continue

    plt.figure(figsize=(6, 4))
    sns.scatterplot(x=valid[col], y=valid["log_price"])
    sns.regplot(x=valid[col], y=valid["log_price"], scatter=False, color="red")

    plt.title(f"{col} vs log_price")
    plt.xlabel(col)
    plt.ylabel("log_price")
    plt.tight_layout()
    plt.savefig(f"plots/scatter_{col}.png")
    print(f"plots/scatter_{col}.png guardado")
    plt.close()

print("\nGenerando heatmap...")
plt.figure(figsize=(10, 8))
corr_matrix = df[important_cols + ["log_price"]].corr()
sns.heatmap(corr_matrix, cmap="coolwarm", center=0, cbar=True)
plt.title("Mapa de calor de correlaciones (filtrado)")
plt.tight_layout()
plt.savefig("plots/corr_heatmap.png")
plt.close()

print("\nTop correlaciones con log_price:")
top = corr.abs().sort_values(ascending=False).head(10)
print(top)
