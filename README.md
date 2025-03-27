# DronSTM
Projekt modułu komunikacji z modułem pomiarowym oraz sterowania elektrozaczepem

# JAK ZAINSTALOWAĆ GITA
1. Pobierz instalator ze strony: https://git-scm.com/downloads oraz napisz do mnie, żebym dał Ci uprawnienia do edytowania repozytorium.
2. Uruchom instalator i postępuj zgodnie z instrukcjami. W większości przypadków domyślne ustawienia są odpowiednie.
3. Po zakończeniu instalacji, przejdź do folderu, w którym przechowywany będzie projekt, kliknij PPM (prawym przyciskiem myszy) i wybierz "Open Git Bash here".

# KONFIGURACJA GITA
1. W terminalu Gita wpisz: "git config --global user.name "nick_name"" oraz "git config --global user.email "twoj_email@example.com"".
2. Następnie wygeneruj klucz SSH za pomocą: "ssh-keygen -t ed25519 -C "twoj_email@example.com"" i 3 razy kliknij enter. Jeśli to nie działa, to wpisz jeszcze raz tę komendę i następnie "/c/id_ed25519" i 2 razy enter.
3. Teraz załóż konto na Githubie i dodaj klucz SSH na stronie: https://github.com/settings/keys, który znajduje się w pliku "id_ed25519.pub".
4. Możesz go wyświetlić za pomocą komendy: "cat ~/.ssh/id_ed25519.pub" lub w Eksploratorze Windows wyszukując: "*id_ed25519.pub".
5. Przejdź do folderu, w którym chcesz przechowywać projekt (jeśli tego wcześniej nie zrobiłeś/aś) i wpisz "git clone https://github.com/hugo2080/Albatros.git", a następnie przejdź do folderu o nazwie Albatros, który właśnie został pobrany.

# ZMIANY
1. Przed wykonaniem następnych kroków, otwórz terminal Gita w folderze DronSTM.
2. Przed każdą zmianą wprowadzoną w projekcie wpisz w terminalu Gita: "git pull origin main".
3. Po wprowadzeniu zmian wpisz: "git add -A", "git commit -am"opis_zmian"" oraz "git push".

# WAŻNE UWAGI
1. Ctrl+C i Ctrl+V nie działają w terminalu Gita. Zamiast nich są odpowiednio Ctrl+Ins oraz Shift+Ins.
2. Zanim zaczniesz coś edytować daj znać innym, że będziesz edytować. Pozwoli to uniknąć trudnych do naprawienia konfliktów.
3. Projekt przechowuj najlepiej na dysku D. Jeśli takowego nie posiadasz, to użyj C, ale najlepiej w folderze, który nie potrzebuje uprawnień administratora.
4. Pod tym linkiem: https://www.youtube.com/watch?v=-lrxvGP-Zd0 jest film, który tłumaczy ten cały proces i jeszcze kilka innych rzeczy o Gicie. Obejrzyj go jeśli instrukcja nie była jasna.
5. Jeśli nawet ten film Ci nie pomógł to napisz na grupie, a Ci pomogę.

Hubert

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 V1.0