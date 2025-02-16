---
author: LCS.Dev
date: "2024-12-23T23:11:30.675410"
title: "Teorema del Limite Centrale"
description: Una breve spiegazione informale del TCL
draft: false
math: true
showToc: true
TocOpen: true
UseHugoToc: true
hidemeta: false
comments: false
disableHLJS: false
disableShare: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowWordCount: true
ShowRssButtonInSectionTermList: true
tags:
  - Probability
  - Math
categories:
  - Math
cover: 
  image: 
  alt: 
  caption: 
  relative: false
  hidden: true
editPost: 
  URL: https://github.com/XtremeXSPC/LCS.Dev-Blog/tree/hostinger/
  Text: Suggest Changes
  appendFilePath: true
---

Il **teorema del limite centrale (TLC)** è un risultato fondamentale nella teoria della probabilità e nella statistica. Esso afferma che, sotto condizioni generali, la somma (o media) di un grande numero di variabili aleatorie indipendenti e identicamente distribuite (i.i.d.) tende a seguire una distribuzione normale, indipendentemente dalla distribuzione originale delle variabili.

---

### Dichiarazione formale

Siano $X_1, X_2, \dots, X_n$ variabili aleatorie i.i.d. con:

- Media $\mu = \mathbb{E}[X_i]$,
- Varianza $\sigma^2 = \text{Var}(X_i)$.

Consideriamo la somma delle $X_i$:
$$
S_n = \sum_{i=1}^n X_i.
$$

La somma normalizzata (o centrata e scalata) è data da:
$$
Z_n = \frac{S_n - n\mu}{\sigma\sqrt{n}}.
$$

Il teorema del limite centrale afferma che:
$$
Z_n \xrightarrow{d} \mathcal{N}(0, 1) \quad \text{quando } n \to \infty,
$$
dove $\xrightarrow{d}$ denota la convergenza in distribuzione e $\mathcal{N}(0, 1)$ rappresenta la distribuzione normale standard.

---

### Interpretazione intuitiva

1. La somma $S_n$ cresce proporzionalmente a $n$, mentre la varianza complessiva aumenta come $\sigma^2 n$.
2. Normalizzando $S_n$ sottraendo la media $n\mu$ e dividendo per $\sigma\sqrt{n}$, otteniamo una variabile con media 0 e varianza 1.
3. Per $n$ sufficientemente grande, la distribuzione di $Z_n$ si avvicina sempre più alla distribuzione normale standard, indipendentemente dalla forma della distribuzione di $X_i$, purché $X_i$ abbia una media e una varianza finite.

---

### Dimostrazione intuitiva (senza rigore completo)

1. **Somma di variabili indipendenti:** La funzione caratteristica della somma $S_n$ è il prodotto delle funzioni caratteristiche delle singole $X_i$:
   $$
   \phi_{S_n}(t) = \left[\phi_{X}(t)\right]^n,
$$
   dove $\phi_X(t) = \mathbb{E}[e^{itX}]$ è la funzione caratteristica di $X_i$.

2. **Espansione di Taylor:** Sviluppando $\phi_X(t)$ intorno a $t = 0$:
   $$
   \phi_X(t) = 1 + i\mu t - \frac{\sigma^2 t^2}{2} + o(t^2).
$$

3. **Normalizzazione:** Considerando la somma normalizzata $Z_n$, la funzione caratteristica diventa:
   $$
   \phi_{Z_n}(t) = \left[ 1 + i\frac{\mu t}{\sqrt{n}} - \frac{\sigma^2 t^2}{2n} + o\left(\frac{1}{n}\right) \right]^n.
$$

4. **Limite:** Per $n \to \infty$, usando $(1 + x/n)^n \to e^x$:
   $$
   \phi_{Z_n}(t) \to e^{-\frac{t^2}{2}},
$$
   che è la funzione caratteristica di $\mathcal{N}(0, 1)$.

---

### Caso delle medie campionarie

Se consideriamo la **media campionaria** <span>$\bar{X}_n = \frac{1}{n} \sum_{i=1}^n X_i$</span>, possiamo riscrivere il teorema del limite centrale come:
$$
\frac{\bar{X}_n - \mu}{\frac{\sigma}{\sqrt{n}}} \xrightarrow{d} \mathcal{N}(0, 1) \quad \text{quando } n \to \infty.
$$

---

### Assunzioni e generalizzazioni

1. **Assunzioni principali:**
   - Le variabili $X_i$ devono essere indipendenti e identicamente distribuite.
   - Devono avere una media finita $\mu$ e una varianza finita $\sigma^2$.

2. **Generalizzazioni:**
   - Per variabili non identicamente distribuite (ma indipendenti), esistono versioni più generali del TLC, purché la somma sia dominata da variabili con varianza finita.
   - Per variabili dipendenti (es. processi stocastici), esistono versioni del TLC che tengono conto della struttura di dipendenza.

---

### Conclusione

Il teorema del limite centrale è cruciale perché giustifica l'uso della distribuzione normale in molte applicazioni pratiche, anche quando la distribuzione originale dei dati non è normale.