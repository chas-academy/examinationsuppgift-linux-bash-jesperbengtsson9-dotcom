#!/bin/bash

 # ----------------------------------------------------------------------------------------------------------------
 # create_users-sh
 #
 # Det här scriptet automatiserar skapandet av nya användare på systemet.
 # För varje användare som anges skapas ett konto, en hemkatalog med tre undermappar: Documents, Downloads och Work.
 # Det skapas även en welcome.txt med ett personligt välkomstmeddelande och en lista över övriga användare.
 #
 # Användning_ sudo ./create_users.sh Anna Bjorn Charlie
 # ----------------------------------------------------------------------------------------------------------------


 # set -e gör så att scriptet avbryts direkt om något kommando misslyckas istället för att forsätta
 # köra med ett felaktigt tillstånd.

  set -e


 # ----------------------------------------------------------------------------------------------------------------
 # Steg 1: Kontrollera att scriptet körs som root
 # ----------------------------------------------------------------------------------------------------------------
 # Kommandon som useradd och chmod kräver root-rättigheter för att fungera.
 # $EUID är den aktuella användarens effektiva ID(userID). Enligt Linux-konventionen har root alltid UID 0, 
 # och alla  # vanliga användare har ett högre nummer. -ne betyder "not equal to" alltså "inte lika med".
 # Om $EUID inte är 0 är vi inte root, och vi avslutar scriptet med ett felmeddelande.

 if [[ "$EUID" -ne 0 ]]; then
         echo "Fel: Detta script måste köras som root. Använd sudo."
         exit 1
 fi

 # ----------------------------------------------------------------------------------------------------------------
 # Steg 2: Kontrollera att minst ett användarnamn har angetts
 # ----------------------------------------------------------------------------------------------------------------
 # $# innehåller antalet argument som skickades in när scriptet kördes.
 # -lt betyder "less than", alltså "mindre än". Om $# är mindre än 1 så har ingen angett något användarnamn
 # och det finns ingenting att göra.
 # $0 är scriptets eget namn. Vi använder det i felmeddelandet tillsammans med <användarnamn1> och de
 # valfria [användarnamn2] [...] för att visa exakt hur kommandot ska skrivas. Hakparanteserna betyder att
 # det är argumentet valfritt, medan de spetsiga paranteserna betyder att det är obligatoriskt.

 if [[ "$#" -lt 1 ]]; then
         echo "Fel: Inga användarnamn angavs."
         echo "Användning: sudo $0 <användarnamn1> [användarnamn2] [...]"
         exit 1
 fi

 # ----------------------------------------------------------------------------------------------------------------
 # Steg 3: Loopa igenom alla angivna användarnamn
 # ----------------------------------------------------------------------------------------------------------------
 # "$@" expanderar till alla argument som skickades in. Vi loopar igenom dem ett i taget
 # och hanterar varje användare i tur och ordning.

 for username in "$@"; do
         echo ">>> Bearbetar användare: $username"

         # --- Kontrollera om användaren redan finns ----
         # Kommandot 'id' hämtar information om en användare om den finns i systemet.
         # >/dev/null skickar bort all utskrift från kommandot, både det som normalt
         # visas i terminalen och eventuella felmeddelanden, så att terminalen hålls
         # ren. Om 'id' lyckas finns användaren redan, och vi hoppar äver den med 'continue'.

         if id "$username" &>/dev/null; then
                 echo " Varning: Användaren '$username' finns redan. Hoppar över."
                 continue
         fi

         # --- Skapar användaren med hemkatalog ---
         # useradd skapar en ny användare i systemet. Vi använder flaggan -m för att
         # hemkatalogen /home/<användarnamn> ska skapas automatiskt, och -s för att
         # ange vilket shell användaren ska använda vid inloggning. Vi anger /bin/bash
         # explicit för att säkerställa att användaren får bash, oavsett vad systemets
         # standardinställning råkar vara.

         useradd -m -s /bin/bash "$username"
         echo " Användaren '$username' har skapats."

         # Vi sparar sökvägen till hemkatalogen i en variabel så vi slipper skriva
         # ut hela sökvägen varje gång vi refererar till den längst ner.

         home_dir="/home/$username"

         # --- Skapa de tre undermapparna i hemkatalogen ---
         # Vi skapar mapparna Documents, Downloads och Work direkt inuti
         # användarens hemkatalog med mkdir.

         mkdir "$home_dir/Documents"
         mkdir "$home_dir/Downloads"
         mkdir "$home_dir/Work"
         echo " Mapparna: Documents, Downloads och Work har skapats."

	 
        # --- Sätt rätt ägare på hemkatalogen och allt innehåll ---
        # Eftersom root kör scriptet kommer alla skapade filer och mappar ägas av root.
        # Vi använder chown för att byta ägare till den nya användaren.
        # Formatet "$username:$username" anger både ägare och grupp. I Linux har
        # varje fil en ägare och en ägargrupp(groupID). Eftersom useradd skapar en
        # primärgrupp med samma namn som användaren sätter vi båda till användarnamnet,
        # till exempel Anna:Anna. Flaggan -R betyder rekursivt, alltså att ändringen
        # gäller hemkatalogen och allt som finns innuti den.

        chown -R "$username:$username" "$home_dir"

        # --- Sätt behörigheter så att bara ägaren kan läsa och skriva ---
        # chmod ändrar behörigheterna på filen och mappar. behörigheter i Linux
        # bygger på tre positioner: ägare, grupp och övriga. Varje position är
        # summan av läsa(4) + skriva(2) + köra/öppna(1).
        # 700 på en mapp ger ägaren full läs-, skriv- och exekveringsrättigheter,
        # medan grupp och övriga inte får någonting alls.
        # Mappar behöver exekveringsrättighet(1) för att kunna öppnas och listas. 

        chmod 700 "$home_dir"
        chmod 700 "$home_dir/Documents"
        chmod 700 "$home_dir/Downloads"
        chmod 700 "$home_dir/Work"

        echo " Behörigheter satta. Bara $username kan komma åt sina mappar och filer."

        # Kontot är skapat, mappstrukturen finns på plats och behörigheter är satta.
	# Welcome.txt skrivs i nästa steg när alla användare finns.

        echo " Klar med $username"
        echo ""

 done

 #-----------------------------------------------------------------------------------------------------------------
 # Steg 4: Skapa welcome.txt för varje användare
 # ----------------------------------------------------------------------------------------------------------------
 # Vi väntar med att skriva welcome.txt tills alla användare har skapats.
 # Anledning är att listan ska innehålla alla övriga användare som finns på systemet. Om vi hade skrivit 
 # filen inne i första loopen skulle den sista användaren saknas i de tidigare användarnas listor, 
 # eftersom de inte fanns i /etc/passwd ännu när deras filer skrevs.
 
  for username in "$@"; do
	

         home_dir="/home/$username"
         welcome_file="$home_dir/welcome.txt"

	 # Med > skriver vi första raden - ett personligt välkomstmeddelande.
	 # Om filen inte finns så skapas den automatiskt av >.
         echo "Välkommen $username" > "$welcome_file"

         # Nu lägger vi till en lista över övriga användare som redan finns på systemet.
         # /etc/passwd är en systemfil som lagrar information om alla konton i systemet.
         # I vårt fall är vi interesserade av varje rads format, som ser ut så här:
         # användarnamn: x : UID(user ID) : GID(groupID) : info : hemkatalog : shell
         #
         # Vi läser igenom /etc/passwd rad för rad med en while-loop.
         # IFS=: talar om för 'read' att kolon ska användas som separator,
         # vilket gör att varje fält på raden automatiskt hamnar i sin egen variabel.
         # Vi namnger variablerna efter vad varje fält innehåller så att koden
         # blir enkel att följa: user_name, password, user_uid, gid, info, home, shell.
         #
         # För varje rad kontrollerar vi tre saker innan vi lägger till namnet i listan:
         # $user_uid -ge 1000 -> UID måste vara 1000 eller högre eftersom systemkonton
         # som root eller daemon har lägre UID.
         #
         # $user_uid -ne 65534 -> vi exkluderar 'nobody', ett speciellt systemkonto
         # med UID 65534 som inte är en riktig användare
         #
         # $user_name != "$username" -> vi exkluderar den användare vi precis skapade
         # så att man inte hälsas välkommen på sig själv

         while IFS=: read -r user_name password user_uid gid info home shell; do
           if [[ "$user_uid" -ge 1000 && "$user_uid" -ne 65534 && "$user_name" != "$username" ]]; then
                   echo "$user_name" >> "$welcome_file"
           fi
        done < /etc/passwd

	# Vi sätter sen 600 på welcome.txt - ägaren för läsa och skriva, ingen annan
	# får någonting alls.
	 
	
	chown "$username:$username" "$welcome_file"
        chmod 600 "$welcome_file"
        echo " welcome.txt skapad för $username."
 done	


 # Vi har loopat igenom alla angivna användarnamn och behandlat dem ett i taget.
 # exit 0 signalerar till systemet att scriptet avslutades utan fel, vilket är
 # standard när allt gått som förväntat.

 echo "Alla användare har bearbetats. Scriptet är klart."
 exit 0

