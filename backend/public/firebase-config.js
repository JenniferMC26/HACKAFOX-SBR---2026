// Config pública del SDK cliente. NUNCA poner credenciales de servidor aquí.
// Reemplazar los valores con los del proyecto en Firebase Console → Project Settings.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getDatabase,
  connectDatabaseEmulator,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js';
import {
  getStorage,
  connectStorageEmulator,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-storage.js';
import {
  getFunctions,
  connectFunctionsEmulator,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-functions.js';
import {
  getAuth,
  signInAnonymously,
  connectAuthEmulator,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js';

const firebaseConfig = {
  apiKey: '',
  authDomain: 'paso.firebaseapp.com',
  databaseURL: 'https://paso-default-rtdb.firebaseio.com',
  projectId: 'paso',
  storageBucket: 'paso.firebasestorage.app',
  messagingSenderId: '',
  appId: '',
};

const app = initializeApp(firebaseConfig);
const db = getDatabase(app);
const storage = getStorage(app);
const functions = getFunctions(app);
const auth = getAuth(app);

// Solo en desarrollo local — el emulador se conecta automáticamente.
if (location.hostname === 'localhost') {
  connectDatabaseEmulator(db, 'localhost', 9000);
  connectStorageEmulator(storage, 'localhost', 9199);
  connectFunctionsEmulator(functions, 'localhost', 5001);
  connectAuthEmulator(auth, 'http://localhost:9099', { disableWarnings: true });
}

// Auth anónimo al cargar — todas las requests llevan idToken.
await signInAnonymously(auth);

export { app, db, storage, functions, auth };
