---
author: LCS.Dev
date: "2024-12-18"
title: "Produttore - Consumatore POSIX"
description: Un esempio del problema "produttore / consumatore"
draft: false
showToc: true
TocOpen: false
UseHugoToc: false
hidemeta: false
comments: true
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
  - Operating-Systems
  - Virtual-Memory
  - Coding
categories:
  - Operating Systems
cover: 
cover_image: 
cover_alt: 
cover_caption: 
cover_relative: false
cover_hidden: true
editPost: 
editPost_URL: https://github.com/XtremeXSPC/LCS.Dev-Blog/tree/hostinger/
editPost_Text: Suggest Changes
editPost_appendFilePath: false
---

**Soluzione al problema del produttore/consumatore con sincronizzazione**

Per risolvere il problema del produttore/consumatore evitando condizioni di gara (*race condition*), *starvation* o *deadlock*, utilizzeremo i semafori POSIX per sincronizzare l'accesso al buffer condiviso.

**Strumenti di sincronizzazione utilizzati:**

- **Semaforo `empty`**: indica il numero di posti vuoti nel buffer.
- **Semaforo `full`**: indica il numero di elementi presenti nel buffer.
- **Semaforo `mutex`**: garantisce l'accesso esclusivo al buffer condiviso per evitare condizioni di gara.

**Implementazione del buffer condiviso:**

Il buffer sarà un buffer circolare implementato in memoria condivisa.

---

#### Codice del Produttore (`producer.c`):

```c {linenos=true}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>           
#include <sys/mman.h>
#include <semaphore.h>
#include <unistd.h>
#include <sys/stat.h>

#define BUFFER_SIZE 10
#define SHM_NAME "/shm_buffer"
#define SEM_EMPTY_NAME "/sem_empty"
#define SEM_FULL_NAME "/sem_full"
#define SEM_MUTEX_NAME "/sem_mutex"

typedef struct {
    int buffer[BUFFER_SIZE];
    int in;
} shared_data;

int main() {
    /* Creazione della memoria condivisa */
    int shm_fd = shm_open(SHM_NAME, O_CREAT | O_RDWR, 0666);
    ftruncate(shm_fd, sizeof(shared_data));
    shared_data *data = mmap(0, sizeof(shared_data), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    
    /* Inizializzazione del buffer */
    data->in = 0;
    
    /* Creazione dei semafori */
    sem_t *empty = sem_open(SEM_EMPTY_NAME, O_CREAT, 0666, BUFFER_SIZE);
    sem_t *full = sem_open(SEM_FULL_NAME, O_CREAT, 0666, 0);
    sem_t *mutex = sem_open(SEM_MUTEX_NAME, O_CREAT, 0666, 1);
    
    int item = 0;
    while(1) {
        /* Produzione di un elemento */
        item++;
        
        /* Attende che ci sia spazio nel buffer */
        sem_wait(empty);
        
        /* Sezione critica: accesso al buffer condiviso */
        sem_wait(mutex);
        data->buffer[data->in % BUFFER_SIZE] = item;
        printf("Produttore ha prodotto: %d\n", item);
        data->in++;
        sem_post(mutex);
        
        /* Incrementa il contatore degli elementi nel buffer */
        sem_post(full);
        
        sleep(1); /* Simula tempo di produzione */
    }
    
    /* Chiusura e rimozione delle risorse */
    sem_close(empty);
    sem_close(full);
    sem_close(mutex);
    munmap(data, sizeof(shared_data));
    close(shm_fd);
    shm_unlink(SHM_NAME);
    sem_unlink(SEM_EMPTY_NAME);
    sem_unlink(SEM_FULL_NAME);
    sem_unlink(SEM_MUTEX_NAME);
    
    return 0;
}
```

---

#### Codice del Consumatore (`consumer.c`):

```c {linenos=true}
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>           
#include <sys/mman.h>
#include <semaphore.h>
#include <unistd.h>
#include <sys/stat.h>

#define BUFFER_SIZE 10
#define SHM_NAME "/shm_buffer"
#define SEM_EMPTY_NAME "/sem_empty"
#define SEM_FULL_NAME "/sem_full"
#define SEM_MUTEX_NAME "/sem_mutex"

typedef struct {
    int buffer[BUFFER_SIZE];
    int out;
} shared_data;

int main() {
    /* Apertura della memoria condivisa */
    int shm_fd = shm_open(SHM_NAME, O_RDWR, 0666);
    shared_data *data = mmap(0, sizeof(shared_data), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    
    /* Apertura dei semafori */
    sem_t *empty = sem_open(SEM_EMPTY_NAME, 0);
    sem_t *full = sem_open(SEM_FULL_NAME, 0);
    sem_t *mutex = sem_open(SEM_MUTEX_NAME, 0);
    
    data->out = 0;
    
    while(1) {
        /* Attende che ci sia almeno un elemento nel buffer */
        sem_wait(full);
        
        /* Sezione critica: accesso al buffer condiviso */
        sem_wait(mutex);
        int item = data->buffer[data->out % BUFFER_SIZE];
        printf("Consumatore ha consumato: %d\n", item);
        data->out++;
        sem_post(mutex);
        
        /* Incrementa il contatore dei posti vuoti nel buffer */
        sem_post(empty);
        
        sleep(2); /* Simula tempo di consumo */
    }
    
    /* Chiusura e rimozione delle risorse */
    sem_close(empty);
    sem_close(full);
    sem_close(mutex);
    munmap(data, sizeof(shared_data));
    close(shm_fd);
    
    return 0;
}
```

---

#### Spiegazione dettagliata:

**1. Semafori utilizzati:**

- **`empty`**: inizializzato a `BUFFER_SIZE`, rappresenta il numero di posti vuoti nel buffer. Il produttore esegue `sem_wait(empty)` prima di produrre un elemento, decrementando il contatore. Se il buffer è pieno (`empty == 0`), il produttore si blocca finché il consumatore non consuma un elemento.
  
- **`full`**: inizializzato a `0`, rappresenta il numero di elementi presenti nel buffer. Il consumatore esegue `sem_wait(full)` prima di consumare un elemento. Se il buffer è vuoto (`full == 0`), il consumatore si blocca finché il produttore non produce un nuovo elemento.
  
- **`mutex`**: inizializzato a `1`, garantisce l'accesso esclusivo al buffer condiviso. Entrambi i processi eseguono `sem_wait(mutex)` prima di accedere al buffer e `sem_post(mutex)` dopo aver terminato.

**2. Buffer circolare:**

- Il buffer è implementato come un array di dimensione `BUFFER_SIZE`.
- Gli indici `in` e `out` gestiscono rispettivamente l'inserimento e la rimozione degli elementi nel buffer in modo circolare.

**3. Prevenzione di condizioni di gara:**

- L'uso del semaforo `mutex` assicura che solo un processo alla volta possa accedere al buffer condiviso, prevenendo condizioni di gara.

**4. Prevenzione di deadlock:**

- L'ordine di acquisizione e rilascio dei semafori è consistente in entrambi i processi.
- Nessun processo mantiene il possesso di un semaforo mentre attende un altro, evitando così un deadlock.

**5. Prevenzione di starvation:**

- I semafori vengono utilizzati in modo equo, e ogni processo attende il suo turno, evitando che uno dei due rimanga in attesa indefinitamente.

---

#### Note aggiuntive:

- **Compilazione**: per compilare i programmi, utilizzare:

```bash
  gcc -o producer producer.c -lrt -pthread
  gcc -o consumer consumer.c -lrt -pthread
```

- **Esecuzione**: eseguire prima il produttore e poi il consumatore in due terminali separati:

```bash
  ./producer
  ./consumer
```

- **Pulizia delle risorse**: assicurarsi che, in caso di interruzione dei programmi, le risorse (memoria condivisa e semafori) vengano rimosse utilizzando `shm_unlink` e `sem_unlink`.

---

Con questa implementazione, il problema del produttore/consumatore viene risolto utilizzando i classici strumenti di sincronizzazione per evitare condizioni di gara, *starvation* o *deadlock*.

---
### Spiegazione dettagliata delle istruzioni nel codice del produttore**

Vediamo passo per passo le istruzioni chiave nel codice del produttore, focalizzandoci sulla struttura `shared_data` e sul motivo per cui è definita in un certo modo.

---

#### Definizione della struttura `shared_data`

```c {linenos=true}
typedef struct {
    int buffer[BUFFER_SIZE];
    int in;
} shared_data;
```

**Spiegazione:**

- **`int buffer[BUFFER_SIZE];`**: dichiara un array di interi di dimensione `BUFFER_SIZE` all'interno della struttura. Questo array rappresenta il buffer circolare condiviso tra il produttore e il consumatore.

- **`int in;`**: è un indice che il produttore utilizza per tenere traccia della posizione corrente in cui inserire il prossimo elemento nel buffer.

La struttura `shared_data` viene mappata interamente nella memoria condivisa, garantendo che sia il buffer che l'indice `in` siano accessibili e consistenti tra il produttore e il consumatore.

---

#### Creazione e mappatura della memoria condivisa

```c {linenos=true}
/* Creazione della memoria condivisa */
int shm_fd = shm_open(SHM_NAME, O_CREAT | O_RDWR, 0666);
ftruncate(shm_fd, sizeof(shared_data));
shared_data *data = mmap(0, sizeof(shared_data), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
```

**Spiegazione:**

- **`shm_open`**: crea un nuovo oggetto di memoria condivisa o apre uno esistente con il nome `SHM_NAME`.
- **`ftruncate`**: imposta la dimensione dell'oggetto di memoria condivisa a `sizeof(shared_data)`.
- **`mmap`**: mappa l'oggetto di memoria condivisa nel proprio spazio di indirizzamento, restituendo un puntatore a `shared_data`.

Con questa mappatura, sia il produttore che il consumatore accedono alla stessa istanza di `shared_data` in memoria condivisa.

---
#### Inizializzazione dei semafori

```c {linenos=true}
/* Creazione dei semafori */
sem_t *empty = sem_open(SEM_EMPTY_NAME, O_CREAT, 0666, BUFFER_SIZE);
sem_t *full = sem_open(SEM_FULL_NAME, O_CREAT, 0666, 0);
sem_t *mutex = sem_open(SEM_MUTEX_NAME, O_CREAT, 0666, 1);
```

**Spiegazione:**

- **`empty`**: inizializzato a `BUFFER_SIZE`, rappresenta il numero di posti vuoti nel buffer.
- **`full`**: inizializzato a `0`, rappresenta il numero di elementi presenti nel buffer.
- **`mutex`**: inizializzato a `1`, garantisce l'accesso esclusivo al buffer condiviso.

---
#### Ciclo di produzione

```c {linenos=true}
while(1) {
    /* Produzione di un elemento */
    item++;
    
    /* Attende che ci sia spazio nel buffer */
    sem_wait(empty);
    
    /* Sezione critica: accesso al buffer condiviso */
    sem_wait(mutex);
    data->buffer[data->in % BUFFER_SIZE] = item;
    printf("Produttore ha prodotto: %d\n", item);
    data->in++;
    sem_post(mutex);
    
    /* Incrementa il contatore degli elementi nel buffer */
    sem_post(full);
    
    sleep(1); /* Simula tempo di produzione */
}
```

**Spiegazione:**

- **`sem_wait(empty);`**: il produttore attende finché c'è almeno un posto vuoto nel buffer.

- **Sezione critica**:

  - **`sem_wait(mutex);`**: acquisisce il semaforo `mutex` per garantire accesso esclusivo al buffer.
  - **Inserimento dell'elemento**: l'elemento `item` viene inserito nella posizione `data->in % BUFFER_SIZE` del buffer.
  - **Aggiornamento dell'indice `in`**: viene incrementato per puntare alla prossima posizione libera.
  - **`sem_post(mutex);`**: rilascia il semaforo `mutex`.
  
- **`sem_post(full);`**: incrementa il semaforo `full` per indicare che c'è un nuovo elemento nel buffer.

---
#### Motivo per cui non è consigliabile usare `int* buffer;` nella struttura `shared_data`

**Definizione alternativa:**

```c {linenos=true}
typedef struct {
    int* buffer;
    int in;
} shared_data;
```

**Motivazione:**

- **Problema dei puntatori in memoria condivisa**:

  - I puntatori memorizzano indirizzi di memoria relativi allo spazio di indirizzamento del processo che li ha creati.
  - Se si utilizza un puntatore all'interno della memoria condivisa, l'indirizzo a cui punta è valido solo nel processo che ha assegnato quel puntatore.

- **Conseguenze**:

  - **Inconsistenza**: il puntatore `buffer` assegnato nel produttore non sarà valido nel consumatore, poiché i due processi hanno spazi di indirizzamento separati.
  - **Accesso non valido**: il consumatore tenterà di accedere a un indirizzo di memoria non valido o errato, causando comportamenti indefiniti o crash.

- **Soluzione con array interno**:

  - Definendo `buffer` come un array all'interno della struttura, l'intero buffer viene memorizzato nella memoria condivisa.
  - Sia il produttore che il consumatore accedono allo stesso array in memoria condivisa, senza problemi di indirizzamento.

**Esempio del problema con `int* buffer;`:**

1. **Allocazione nel produttore**:

   - Se nel produttore si fa `data->buffer = malloc(BUFFER_SIZE * sizeof(int));`, la memoria allocata da `malloc` non è condivisa, ma locale al processo.

2. **Accesso nel consumatore**:

   - Il consumatore accederà a `data->buffer`, che contiene un indirizzo di memoria valido solo nel produttore, portando a errori.

---
#### Come utilizzare un puntatore in memoria condivisa (non consigliato in questo caso)

Se si desidera utilizzare un puntatore all'interno di una struttura in memoria condivisa, è necessario assicurarsi che:

- **Allocazione nella memoria condivisa**:

  - La memoria a cui punta il puntatore deve essere allocata all'interno della stessa memoria condivisa.

- **Gestione degli offset**:

  - Invece di utilizzare indirizzi assoluti, si possono utilizzare offset relativi all'inizio della memoria condivisa.

**Implementazione complessa e soggetta a errori**:

- Richiede una gestione manuale degli indirizzi e degli offset.
- Aumenta la complessità del codice e la possibilità di introdurre bug.

**Perché usare un array invece di un puntatore:**

- **Semplicità**: l'array è direttamente incorporato nella struttura `shared_data`, che è interamente mappata nella memoria condivisa.
- **Sicurezza**: evita problemi di indirizzamento e accesso non valido alla memoria.
- **Portabilità**: il codice è più portabile e meno soggetto a errori legati all'architettura o al sistema operativo.

**Raccomandazione:**

- **Evitare l'uso di puntatori in strutture condivise tra processi**, a meno che non sia strettamente necessario e si abbia una solida comprensione della gestione della memoria tra processi.

- **Utilizzare strutture di dati che possono essere completamente mappate nella memoria condivisa**, come array o strutture senza puntatori interni.

---

Non è consigliabile utilizzare la struttura proposta con `int* buffer;` perché i puntatori non sono validi attraverso i confini dei processi quando si utilizza la memoria condivisa. Definire `buffer` come un array all'interno della struttura `shared_data` garantisce che l'intero buffer sia effettivamente condiviso tra il produttore e il consumatore, evitando problemi di indirizzamento e garantendo la corretta sincronizzazione e comunicazione tra i processi.

---
