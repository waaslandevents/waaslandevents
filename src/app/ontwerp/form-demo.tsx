"use client";

import { useState } from "react";
import { Button, ChoiceChip, Field, Input, Select, Stepper, Textarea } from "@/components/ui";

const STEPS = ["Event", "Datum", "Locatie", "Gasten", "Behoeften", "Budget", "Extra", "Contact"];

export function FormDemo() {
  const [step, setStep] = useState(2);
  return (
    <div className="space-y-8">
      <Stepper steps={STEPS} current={step} />
      <div className="flex gap-2">
        <Button variant="ghost" size="sm" onClick={() => setStep((s) => Math.max(0, s - 1))}>
          Vorige stap
        </Button>
        <Button variant="outline" size="sm" onClick={() => setStep((s) => Math.min(STEPS.length - 1, s + 1))}>
          Volgende stap
        </Button>
      </div>
      <div className="grid gap-6 sm:grid-cols-2">
        <Field label="Gemeente" hint="We tonen enkel leveranciers die hier actief zijn.">
          {({ id, describedBy }) => (
            <Select id={id} aria-describedby={describedBy} defaultValue="">
              <option value="" disabled>
                Kies je gemeente
              </option>
              <option>Beveren</option>
              <option>Sint-Niklaas</option>
            </Select>
          )}
        </Field>
        <Field label="Aantal gasten" error="Vul een aantal in, bijvoorbeeld 80.">
          {({ id, describedBy, invalid }) => (
            <Input id={id} type="number" inputMode="numeric" aria-describedby={describedBy} aria-invalid={invalid} />
          )}
        </Field>
        <Field label="Budget" optional className="sm:col-span-2">
          {({ id, describedBy }) => <Input id={id} aria-describedby={describedBy} placeholder="bv. € 500 – € 750" />}
        </Field>
        <Field label="Extra informatie" optional className="sm:col-span-2">
          {({ id, describedBy }) => (
            <Textarea id={id} aria-describedby={describedBy} placeholder="Wat moeten de leveranciers nog weten?" />
          )}
        </Field>
      </div>
      <fieldset>
        <legend className="text-sm font-semibold">Wat heb je nodig?</legend>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <ChoiceChip name="nodig" value="photobooth" label="Photobooth" description="vanaf € 299" defaultChecked />
          <ChoiceChip name="nodig" value="dj" label="DJ" description="vanaf € 450" />
          <ChoiceChip name="nodig" value="catering" label="Catering" />
          <ChoiceChip name="nodig" value="tent" label="Tent" />
        </div>
      </fieldset>
      <fieldset>
        <legend className="text-sm font-semibold">Binnen of buiten?</legend>
        <div className="mt-3 grid gap-3 sm:grid-cols-3">
          <ChoiceChip type="radio" name="io" value="binnen" label="Binnen" />
          <ChoiceChip type="radio" name="io" value="buiten" label="Buiten" defaultChecked />
          <ChoiceChip type="radio" name="io" value="beide" label="Beide" />
        </div>
      </fieldset>
    </div>
  );
}
