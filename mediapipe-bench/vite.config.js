import { readFileSync } from "node:fs";

const https = process.env.AKI_HTTPS_KEY && process.env.AKI_HTTPS_CERT
  ? {
      key: readFileSync(process.env.AKI_HTTPS_KEY),
      cert: readFileSync(process.env.AKI_HTTPS_CERT),
    }
  : undefined;

export default {
  server: { https },
};
