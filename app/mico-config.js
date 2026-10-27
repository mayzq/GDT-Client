
"use strict";

const fs = require("fs");
const path = require("path");

module.exports = function getMicoConfig(shippedDir) {
  const file = path.join(shippedDir, "build.json");

  // Sem build.json, usa o preview (na logica)
  if (!fs.existsSync(file)) {
    return {
      channel: "preview",
      userDataFolder: "Mico Preview"
    };
  }

  let build;

  try {
    const content = fs.readFileSync(file, "utf8")
      .replace(/^\uFEFF/, "");

    build = JSON.parse(content);
  } catch (error) {
    throw new Error(
      "Mico: build.json invalido: " + error.message
    );
  }

  if (!build || typeof build !== "object" ||
      Array.isArray(build)) {
    throw new Error("Mico: configuracao de build invalida.");
  }

  const channel = build.channel === undefined
    ? "preview"
    : build.channel;

  if (channel !== "preview" && channel !== "release") {
    throw new Error(
      "Mico: canal desconhecido: " + channel
    );
  }

  // A versao oficial exige um endereco de servidor valido.
  if (channel === "release") {
    let server;

    try {
      server = new URL(build.server);
    } catch (error) {
      throw new Error(
        "Mico: endereco do servidor oficial invalido."
      );
    }

    if (!["http:", "https:"].includes(server.protocol) ||
        !server.hostname) {
      throw new Error(
        "Mico: protocolo ou endereco do servidor invalido."
      );
    }
  }

  return {
    channel,
    userDataFolder: channel === "release"
      ? "Mico"
      : "Mico Preview"
  };
};
