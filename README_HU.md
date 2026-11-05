# TWINZ BARBER – ingyenes digitális hűségprogram

Ez egy induló, működőképes webalkalmazás-forráskód. A felület és az adatbázis ingyenes csomagokkal elindítható. **A valódi Apple Wallet / Google Wallet kártyakibocsátás nincs benne**, mert azokhoz külön fejlesztői kibocsátói beállítások és adott esetben díjak szükségesek. A vendég a webappot hozzáadhatja a telefonja főképernyőjéhez; a saját QR-kódját ott mutathatja fel.

## Mit tud?
- Vendégregisztráció és belépés e-mail/jelszóval.
- Egyedi vendég QR-kód.
- Adminisztrátori kameraolvasás.
- 8 fizetős hajvágás után jutalom.
- A jutalom beváltása és a számláló nullázása az adatbázisban.
- Alap vendéglista.
- Mobilbarát, fekete-ezüst PWA felület.

## 1. Supabase projekt
1. Nyisd meg: https://supabase.com és hozz létre ingyenes projektet.
2. A projektben nyisd meg az SQL Editor menüt.
3. Másold be és futtasd le a `supabase/schema.sql` teljes tartalmát.
4. Project Settings → API alatt másold ki a Project URL-t és az anon/public key-t.
5. Nyisd meg a `config.js` fájlt, és illeszd be ezeket:
   - `SUPABASE_URL`: Project URL
   - `SUPABASE_ANON_KEY`: anon/public key
   **Soha ne használd a service_role kulcsot a böngészőben!**

## 2. Admin fiók létrehozása
1. Tedd közzé a weboldalt (lásd lent).
2. Regisztrálj a saját e-mail címeddel a weboldalon.
3. Supabase → Authentication → Users alatt másold ki a saját User ID értékedet.
4. SQL Editorban futtasd ezt, a saját UUID-dal behelyettesítve:

```sql
update public.profiles
set is_admin = true
where id = 'IDE_MASOLD_A_SAJAT_USER_ID_T';
```

5. Jelentkezz ki, majd vissza. Ekkor az Admin felület jelenik meg.

**Nagyon fontos:** az admin jogosultságot csak a saját, megbízható fiókodnak add meg. Ne tedd adminná a vendégeket.

## 3. Közzététel GitHub Pages segítségével
1. Hozz létre egy GitHub-fiókot: https://github.com/signup
2. Hozz létre egy új, nyilvános repository-t, például `twinz-barber-loyalty` néven.
3. Töltsd fel a ZIP-ben lévő fájlokat és mappákat (ne magát a ZIP-et).
4. A repository Settings → Pages részén válaszd a Deploy from a branch opciót.
5. Branch: `main`, folder: `/ (root)`, majd Save.
6. Pár perc múlva megjelenik a weboldalad címe.

## 4. Első teszt
1. Regisztrálj egy külön tesztvendég e-mail címmel.
2. Nyisd meg a vendégkártyát egy másik telefonon.
3. Admin fiókkal lépj be a saját telefonodon, és olvasd be a vendég QR-kódját.
4. A 8. rögzített fizetős látogatás után megjelenik a jutalom.
5. Ha a vendégnek már van beváltható jutalma, a QR beolvasása után megjelenik az **Ingyenes hajvágás beváltása** gomb. Csak akkor nyomd meg, ha a vendég ténylegesen most használja fel a jutalmát. A beváltás után a számláló automatikusan nullázódik.

## Biztonság és adatvédelem
- A QR-kód egy véletlenszerű azonosító; ne legyen benne e-mail vagy név.
- A látogatásrögzítés csak admin jogosultsággal működik.
- Az anon/public kulcs böngészőben használható, a service_role kulcs nem.
- Valódi vendégadatok előtt készíts rövid adatkezelési tájékoztatót, kérj megfelelő hozzájárulást, és csak szükséges adatot tárolj.
- A kameraolvasás HTTPS-en működik megbízhatóan.
- A QR-kódos rendszer nem automatikus fizetésellenőrzés: a barbernek csak a ténylegesen kifizetett hajvágás után szabad pecsétet adnia.

## Korlátok
A Supabase és GitHub ingyenes csomagjai használati limitekkel és feltételekkel rendelkeznek, amelyek változhatnak. A külső QR-kód és Supabase JavaScript könyvtár CDN-ről töltődik be, ezért az első használathoz internetkapcsolat kell.
