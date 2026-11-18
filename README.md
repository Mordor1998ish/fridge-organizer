# Fridge Organizer 🧊

Domowa aplikacja (PWA) do przepisów, lodówki, planu tygodnia i zakupów – wspólna dla całego domu, działa na Androidzie i iPhonie, także bez internetu.

**Adres aplikacji:** https://mordor1998ish.github.io/fridge-organizer/

## Instalacja na telefonie
- **Android (Chrome):** otwórz adres → menu ⋮ → **Zainstaluj aplikację** / **Dodaj do ekranu głównego**.
- **iPhone (Safari):** otwórz adres → przycisk **Udostępnij** → **Do ekranu początkowego**.

Przy pierwszym uruchomieniu wpisz **kod domowy** (ten sam na wszystkich telefonach) albo utwórz nowy dom.

## Jak to działa
- Dane domu są w bazie Supabase (tabela `fo_households`), dostęp tylko przez funkcje z kodem domowym (w bazie zapisany jest wyłącznie skrót SHA-256 kodu).
- Każda zmiana zapisuje się najpierw w telefonie, potem trafia do bazy. Bez internetu aplikacja działa normalnie i wysyła zmiany po połączeniu. Zmiany dwóch osób są scalane.
- Aktualizacje: nowa wersja z tego repozytorium wczytuje się automatycznie przy następnym otwarciu aplikacji.

## Konfiguracja bazy (jednorazowo)
Supabase → **SQL Editor** → **New query** → wklej zawartość [`supabase/setup.sql`](supabase/setup.sql) → **Run**.

## Pliki
- `index.html` – cała aplikacja
- `sw.js` – service worker (offline, aktualizacje)
- `manifest.webmanifest`, ikony – instalacja na telefonie
- `supabase/setup.sql` – tabela i funkcje bazy
