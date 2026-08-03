GUESTLY PR — BUILD 5 CORRETTA

Correzioni principali:
- Rimossi entitlement e container CloudKit non configurati, che potevano bloccare "Prepare Build for App Store Connect".
- Build incrementata a 5.
- Eliminati gli avvisi Swift relativi alle closure @MainActor nelle impostazioni.
- Compatibilità iPhone e iPad mantenuta.
- Rendiconto, eventi, clienti e modalità ingresso invariati.

APERTURA:
1. Apri ListUpPR.xcodeproj.
2. Seleziona il target ListUpPR > Signing & Capabilities.
3. Scegli il tuo Team e verifica il Bundle Identifier.
4. Product > Archive.

Questa build usa salvataggio locale e non richiede la capability iCloud/CloudKit.
