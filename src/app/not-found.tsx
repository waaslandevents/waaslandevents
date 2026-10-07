import { ButtonLink, Container } from "@/components/ui";

export default function NotFound() {
  return (
    <Container className="py-24">
      <h1 className="text-4xl">Deze pagina bestaat (nog) niet</h1>
      <p className="mt-4 max-w-[55ch] text-lg text-ink-muted">
        Misschien is de link veranderd. Zoek je iets voor je event? Start je aanvraag en we helpen je verder.
      </p>
      <div className="mt-8 flex flex-wrap gap-3">
        <ButtonLink href="/aanvraag">Start je aanvraag</ButtonLink>
        <ButtonLink href="/" variant="outline">
          Naar de homepage
        </ButtonLink>
      </div>
    </Container>
  );
}
