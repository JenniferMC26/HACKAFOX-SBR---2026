# 🦶 PASO — Plataforma de Accesibilidad para Servicios y Orientación

![Flutter](https://img.shields.io/badge/Flutter-3.44.0-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12.0-0175C2?style=flat&logo=dart&logoColor=white)
![Google Maps](https://img.shields.io/badge/Google%20Maps-Platform-4285F4?style=flat&logo=googlemaps&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-Vision%20API-8E75B2?style=flat&logo=google&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Realtime-FFCA28?style=flat&logo=firebase&logoColor=black)
![Hackafox](https://img.shields.io/badge/Hackafox-2026-FF6B35?style=flat)

> **Hackafox 2026 · Track 01 · Tijuana Sin Barreras**

---

## 🚨 El problema

Tijuana no fue diseñada pensando en todos.

**170,000 personas** con discapacidad motriz, adultos mayores y familias enfrentan banquetas destruidas y transporte inaccesible cada día. Llegar al IMSS puede ser una odisea de 2 horas — o simplemente imposible.

Los sistemas de navegación tradicionales asumen movilidad estándar. No existe una herramienta que trace rutas seguras según el tipo de movilidad del usuario ni que mantenga un mapa vivo de las barreras físicas de la ciudad.

---

## 💡 Nuestra solución

**PASO** es una plataforma de ruteo accesible en tiempo real que:

- 🗺️ Traza rutas personalizadas según el tipo de movilidad del usuario
- 📸 Permite reportar barreras físicas con una foto analizada automáticamente por IA
- 🔴 Mantiene un mapa vivo con alertas de barreras reportadas por la comunidad
- 🆘 Incluye botón de pánico para emergencias en ruta
- ♿ Está diseñada con estándares de accesibilidad WCAG AA

---

## 🎯 Propuesta de valor

> *"PASO no solo te dice cómo llegar — te dice cómo llegar de forma segura, con rutas validadas por tu comunidad y actualizadas en tiempo real."*

Lo que nos diferencia:
- **Ruteo por perfil de movilidad** — rutas distintas para silla de ruedas, bastón, andadera o adulto mayor
- **Reporte de un solo toque** — foto → IA clasifica la barrera → mapa actualizado al instante
- **Botón de pánico** — alerta al contacto de emergencia con ubicación exacta
- **Diseño radicalmente inclusivo** — construido para el usuario más vulnerable, no como afterthought

---

## 📱 Pantallas

| Pantalla | Descripción |
|----------|-------------|
| 🌟 Splash Screen | Isotipo de PASO con animación de entrada |
| 🔐 Login | Acceso con teléfono y contraseña |
| 📝 Registro | Nombre completo, teléfono y contraseña con validación |
| ♿ Onboarding Movilidad | Selección de tipo de movilidad (5 opciones) |
| 📞 Onboarding Emergencia | Registro de contacto de emergencia (opcional) |
| 🗺️ Mapa Principal | Google Maps real de Tijuana con búsqueda de destino |
| 🛣️ Detalles de Ruta | Tiempo, distancia y descripción por tipo de movilidad |
| 🧭 Navegación Activa | Mapa con ruta trazada, marcadores de barreras y alertas |
| 📸 Reporte de Barrera | Cámara real + análisis automático por Gemini Vision |
| ✅ Confirmación de Reporte | Resumen del reporte e impacto en la comunidad |
| 🆘 Botón de Pánico | Cuenta regresiva y alerta de emergencia |

---

## 🛠️ Tecnologías

### Frontend
| Tecnología | Versión | Uso |
|-----------|---------|-----|
| Flutter | 3.44.0 | Framework multiplataforma (Android + Web) |
| Dart | 3.12.0 | Lenguaje de programación |
| google_maps_flutter | ^2.9.0 | Mapa real de Tijuana con marcadores y rutas |
| image_picker | ^1.1.0 | Cámara real para reporte de barreras |
| permission_handler | ^11.3.0 | Permisos de ubicación, cámara y micrófono |
| flutter_launcher_icons | ^0.14.1 | Ícono personalizado de PASO |

### Backend *(ver repositorio de backend)*
| Tecnología | Uso |
|-----------|-----|
| Firebase Realtime Database | Sincronización de reportes en tiempo real |
| Gemini Vision API | Análisis automático de fotos de barreras |
| BigQuery + Antigravity | Analítica urbana y mapa de calor |
| Google Maps Platform | Ruteo accesible y geolocalización |

---

## 🏗️ Arquitectura del Frontend

El proyecto implementa **Screaming Architecture** orientada a features:

```
lib/
├── main.dart                          # Entrada de la app
├── app.dart                           # MaterialApp + tema + rutas
│
├── features/
│   ├── auth/
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       ├── onboarding_mobility_screen.dart
│   │       └── onboarding_emergency_screen.dart
│   ├── routing/
│   │   ├── screens/
│   │   │   ├── starting_screen.dart
│   │   │   ├── route_details_screen.dart
│   │   │   └── navigation_screen.dart
│   │   └── widgets/
│   │       ├── mobility_card.dart
│   │       ├── route_info_card.dart
│   │       └── alert_banner.dart
│   ├── reporting/
│   │   ├── screens/
│   │   │   ├── report_barrier_screen.dart
│   │   │   └── barrier_confirmed_screen.dart
│   │   └── widgets/
│   │       ├── severity_chip.dart
│   │       ├── photo_preview_card.dart
│   │       └── report_summary_card.dart
│   └── emergency/
│       └── screens/
│           └── panic_screen.dart
│
└── shared/
    ├── theme/
    │   ├── app_colors.dart
    │   ├── app_theme.dart
    │   └── app_text_styles.dart
    ├── widgets/
    │   ├── primary_button.dart
    │   ├── map_placeholder.dart
    │   └── status_chip.dart
    ├── services/
    │   └── permission_service.dart
    └── constants/
        ├── app_routes.dart
        └── app_strings.dart
```

---

## 🎨 Sistema de diseño

| Token | Valor | Uso |
|-------|-------|-----|
| `primary` | `#4285F4` | Botones, acciones, selección |
| `warning` | `#FBBC04` | Alertas, FAB de reporte |
| `success` | `#34A853` | Confirmaciones, rutas seguras |
| `danger` | `#EA4335` | Pánico, barreras de alta severidad |
| `secondary` | `#9AA0A6` | Texto secundario, placeholders |

- Tipografía mínima: **16sp** para legibilidad en adultos mayores
- Tap targets mínimos: **64dp** para usuarios con movilidad reducida
- Contraste: **WCAG AA** en todos los textos

---

## 🚀 Cómo correr el proyecto localmente

### Requisitos previos
- Flutter 3.44.0 o superior
- Dart 3.12.0 o superior
- Android Studio o VS Code con extensión Flutter
- Dispositivo Android físico o emulador (API 21+)

### Instalación

```bash
# 1. Clona el repositorio
git clone https://github.com/JenniferMC26/HACKAFOX-SBR---2026.git

# 2. Entra a la carpeta del proyecto
cd HACKAFOX-SBR---2026/camino_front

# 3. Instala las dependencias
flutter pub get

# 4. Corre en Android
flutter run

# 5. Corre en Chrome
flutter run -d chrome
```

### Credenciales de prueba *(solo modo desarrollo)*
```
Teléfono: 6641234567
Contraseña: 123456
```

### Generar APK
```bash
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

---

## ♿ Accesibilidad

PASO está construido siguiendo los estándares **WCAG AA**:

- ✅ Contraste mínimo 4.5:1 en todos los textos
- ✅ Tap targets mínimos de 64dp
- ✅ Etiquetas `Semantics()` en todos los elementos interactivos
- ✅ Textos mínimos de 16sp para legibilidad en adultos mayores
- ✅ Compatible con lectores de pantalla (TalkBack en Android)
- ✅ Diseño responsive — funciona en móvil y web

---

## 🔐 Permisos requeridos

### Android
| Permiso | Uso |
|---------|-----|
| `ACCESS_FINE_LOCATION` | Ubicación exacta para ruteo accesible |
| `ACCESS_COARSE_LOCATION` | Ubicación aproximada como fallback |
| `CAMERA` | Fotografiar barreras físicas para reportes |
| `RECORD_AUDIO` | Entrada de voz para búsqueda de destino |
| `INTERNET` | Sincronización en tiempo real con Firebase |

### Web (Chrome)
| Permiso | Uso |
|---------|-----|
| Ubicación | Solicitada por el navegador al cargar el mapa |
| Cámara | Solicitada al iniciar un reporte de barrera |
| Micrófono | Solicitada al usar búsqueda por voz |

---

## 📊 Impacto potencial

> PASO puede beneficiar directamente a las **170,000 personas** con discapacidad motriz en Tijuana, además de adultos mayores y familias con carriolas — aproximadamente el **10% de la población** de la ciudad.

---

## 👥 Equipo — Hackafox 2026

| Rol | Integrante | GitHub |
|-----|-----------|--------|
| Frontend Developer | Jennifer MC | [@JenniferMC26](https://github.com/JenniferMC26) |
| Frontend Developer | *(nombre compañera)* | *(usuario GitHub)* |
| Backend Developer | *(nombre)* | *(usuario GitHub)* |
| Backend Developer | *(nombre)* | *(usuario GitHub)* |

---

## 📄 Licencia

Proyecto desarrollado para **Hackafox 2026 · Track 01 · Tijuana Sin Barreras**.

---

<div align="center">
  <strong>PASO — Tu ciudad, accesible para todos 🦶</strong><br>
  <sub>Hackafox 2026 · Tijuana, Baja California, México</sub>
</div>
