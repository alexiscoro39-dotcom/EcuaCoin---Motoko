import { Actor, HttpAgent } from '@dfinity/agent';
import { idlFactory } from '../../../declarations/ECUACOIN_EC_backend/ECUACOIN_EC_backend.did.js';

const LOCAL_CONFIG = {
  host: "http://127.0.0.1:4943",
  backendCanisterId: "bkyz2-fmaaa-aaaaa-qaaaq-cai",
};

// Actor "anónimo" por defecto (antes de iniciar sesión). Solo para pruebas sin auth.
export let backend = Actor.createActor(idlFactory, {
  agent: new HttpAgent({ host: LOCAL_CONFIG.host }),
  canisterId: LOCAL_CONFIG.backendCanisterId
});

// Llamar justo después del login, con la identity real del usuario.
export async function setIdentity(identity) {
  const agent = new HttpAgent({
    identity,
    host: LOCAL_CONFIG.host
  });

  await agent.fetchRootKey();

  backend = Actor.createActor(idlFactory, {
    agent,
    canisterId: LOCAL_CONFIG.backendCanisterId
  });

  return backend;
}