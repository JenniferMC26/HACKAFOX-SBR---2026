# 🦶 PASO — Tijuana sin barreras

> **Hackafox 2026 · Track 01**
> Una app de rutas accesibles para que todos puedan moverse por Tijuana.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)
![Google Maps](https://img.shields.io/badge/Google%20Maps-Platform-4285F4?logo=googlemaps&logoColor=white)

---

## ✨ ¿Qué hace?

PASO traza rutas según tu **tipo de movilidad** (silla de ruedas, bastón, andadera, adulto mayor…), te avisa de barreras en el camino y te deja **reportar nuevas con una foto** que la IA clasifica al instante. También incluye un **botón de pánico** que alerta a tu contacto de emergencia con tu ubicación.

- 🗺️ Rutas personalizadas por perfil de movilidad
- 📸 Reporte de barreras con foto + IA
- 🔴 Mapa vivo con alertas de la comunidad
- 🆘 Botón de pánico con ubicación
- ♿ Diseño WCAG AA (contraste, tap targets, lectores de pantalla)

---

## 🧱 Estructura del repo

```
HACKAFOX-SBR---2026/
├── camino_front/   # App Flutter (Android + Web)
└── backend/        # Supabase: schema, seeds, Docker
```

## 🛠️ Stack

**Frontend:** Flutter · Dart · google_maps_flutter · image_picker · Dijkstra sobre CSV de calles
**Backend:** Supabase (Auth + Postgres + Realtime) · Groq (clasificación de imágenes) · Google Maps Platform

---

## 🚀 Correrlo en local

**Requisitos:** Flutter 3.44+, Dart 3.12+, una API key de Google Maps y un proyecto de Supabase.

```bash
git clone https://github.com/JenniferMC26/HACKAFOX-SBR---2026.git
cd HACKAFOX-SBR---2026/camino_front

# 1. Copia los archivos de ejemplo y rellena tus claves
cp lib/core/config/secrets.example.dart lib/core/config/secrets.dart
cp .env.example .env

# 2. Instala dependencias y corre
flutter pub get
flutter run            # Android
flutter run -d chrome  # Web
```

> 🔐 `secrets.dart` y `.env` están gitignoreados — nunca subas tus claves al repo.

---

## 👥 Equipo

| Rol      | Integrante                    | GitHub                                              |
| -------- | ----------------------------- | --------------------------------------------------- |
| Frontend | Jennifer MC                   | [@JenniferMC26](https://github.com/JenniferMC26)    |
| Frontend | Prina Meredith                | [@MerelyMeredith](https://github.com/MerelyMeredith)|
| Backend  | Angel Castro                  | [@Tenshi145](https://github.com/Tenshi145)          |
| Backend  | Yael Kristoph Triana Sánchez  | [@YaelTriana](https://github.com/YaelTriana)        |

---

<div align="center">
  <strong>PASO — tu ciudad, accesible para todos 🦶</strong><br>
  <sub>Hackafox 2026 · Tijuana, BC</sub>
</div>
