// Importa Modal dall'API di Obsidian
const { Modal } = require('obsidian');

// Importa la classe Notice per mostrare messaggi all'utente
import Notice from 'src/notice';

// Classe per creare un modal per inserire il titolo del post
class BlogPostModal extends Modal {
    constructor(app, callback) {
        super(app);
        this.callback = callback;
    }

    onOpen() {
        let { contentEl } = this;
        contentEl.createEl("h2", { text: "Inserisci il titolo dell'articolo" });

        let input = contentEl.createEl("input", { type: "text", placeholder: "Titolo..." });
        input.addClass("blog-title-input");

        let submitBtn = contentEl.createEl("button", { text: "Crea Post" });
        submitBtn.addClass("mod-cta");

        submitBtn.onclick = () => {
            const title = input.value.trim();
            if (title) {
                this.callback(title);
                this.close();
            } else {
                new Notice("Errore: Titolo non può essere vuoto!");
            }
        };

        input.focus();
    }

    onClose() {
        let { contentEl } = this;
        contentEl.empty();
    }
}

// Funzione per creare un nuovo post nel blog
async function newBlogPost(tp) {
	const blogPath = "XSPC-Vault/Blog/posts";

	new BlogPostModal(app, async (title) => {
	// Genera timestamp corrente in formato ISO 8601
	const now = new Date();
	const isoDate = now.toISOString(); // "YYYY-MM-DDTHH:MM:SS.ssssss"
	const shortDate = isoDate.split("T")[0]; // Solo "YYYY-MM-DD"

	// Nome file basato sul titolo
	const fileName = `${title.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.md`;
	const filePath = `${blogPath}/${fileName}`;

	// Contenuto della nuova nota con il frontmatter personalizzato
	const content = `---
author: LCS.Dev
date: "${isoDate}"
title: "${title}"
description:
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
categories:
cover:
  image:
  alt:
  caption:
  relative: false
  hidden: true
editPost:
  URL:
  Text: Suggest Changes
  appendFilePath: true
---
`;
       // Controlla se il file esiste già
	   const existingFile = app.vault.getAbstractFileByPath(filePath);
	   if (existingFile) {
		   new Notice(`Il file ${fileName} esiste già!`);
	   } else {
		   try {
			   await app.vault.create(filePath, content);
			   new Notice(`Nuovo articolo creato: ${filePath}`);
		   } catch (error) {
			   console.error("Errore nella creazione della nota:", error);
			   new Notice("Errore durante la creazione della nota.");
		   }
	   }
   }).open();
}

// Esporta la funzione per Templater
module.exports = newBlogPost;
