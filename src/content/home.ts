/**
 * Homepage-teksten. Fase 10 verplaatst dit naar cms_blocks (key 'home.*'),
 * met dit bestand als terugvaloptie.
 */
export const home = {
  hero: {
    title: "Alles voor jouw event. Lokaal geregeld.",
    lead:
      "Organiseer je een feest, bedrijfsdag, schoolfeest, huwelijk of ander evenement? WaaslandEvents helpt je eenvoudig de juiste leveranciers in het Waasland te vinden.",
    primary: "Start je aanvraag",
    secondary: "Ik weet wat ik zoek",
    pickerTitle: "Wat organiseer je?",
    pickerHint: "Kies je event en we vragen enkel wat nodig is.",
  },
  steps: {
    title: "Hoe werkt het?",
    items: [
      {
        title: "Vertel ons wat je organiseert",
        body: "Eén aanvraag: datum, plaats, aantal gasten en wat je nodig hebt. Twee minuten werk.",
      },
      {
        title: "Wij zoeken passende lokale partners",
        body: "We bekijken je aanvraag zelf en kiezen per onderdeel maximaal drie leveranciers die bij je event passen.",
      },
      {
        title: "Je komt rechtstreeks in contact",
        body: "De leveranciers nemen contact met je op met een offerte. Jij kiest, zonder verplichtingen.",
      },
    ],
  },
  audiences: {
    title: "Voor elk type evenement",
    items: [
      { title: "Privé", body: "Verjaardagen, communies, huwelijken, babyborrels, tuin- en familiefeesten." },
      { title: "Bedrijven", body: "Personeelsfeesten, teambuildings, klantenevents, opendeurdagen en jubilea." },
      { title: "Scholen", body: "Schoolfeesten, sportdagen, proclamaties en schoolfuiven." },
      { title: "Verenigingen", body: "Fuiven, eetfestijnen, quizzen, clubfeesten en buurtfeesten." },
      { title: "Publieke events", body: "Gemeentelijke en culturele evenementen, markten en goede doelen." },
    ],
  },
  why: {
    title: "Waarom WaaslandEvents?",
    items: [
      { title: "Lokaal", body: "Enkel leveranciers die in jouw gemeente actief zijn." },
      { title: "Eén aanvraag", body: "Je vertelt je verhaal één keer, niet tien keer." },
      { title: "Gecontroleerde partners", body: "We kijken bedrijfsgegevens en aanbod na voor iemand online komt." },
      { title: "Geen spam", body: "Maximaal drie leveranciers per onderdeel. Geen lijst van twintig." },
      { title: "Onafhankelijk", body: "Niemand betaalt om bovenaan te staan. We kiezen wie past." },
      { title: "Gratis voor jou", body: "Je betaalt niets aan WaaslandEvents, enkel aan de leverancier die je kiest." },
    ],
  },
  suppliers: {
    title: "Ontvang nieuwe klanten zonder abonnement.",
    body: "Geen maandelijkse kost. Geen instapkost. Alleen commissie wanneer je via WaaslandEvents daadwerkelijk een opdracht binnenhaalt.",
    cta: "Word WaaslandEvents partner",
  },
  closing: {
    title: "Jij organiseert. Wij helpen je regelen.",
    body: "Van een verjaardagsfeest tot een bedrijfsfeest, huwelijk, schoolfeest of groot evenement: WaaslandEvents helpt je de juiste lokale partners te vinden.",
    cta: "Start je aanvraag",
  },
} as const;
