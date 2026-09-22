# What the parser reads

The expressions ChronoPT understands, and how it reads the ones that could
mean more than one thing.

## Days

- Relative: hoje, amanhã, depois de amanhã, daqui 2 dias, em três semanas,
  daqui a 1 ano, prazo de 5 dias.
- Weekdays: sexta que vem, próxima sexta, na terça-feira, sábado agora, quinta
  dessa semana, 6ª feira, na seg, sexta, 25.
- Dates: 25/09, 25/09/2026, 25-12-2027, 25.12.2027, 10/out, 2026-10-15, 15 de
  outubro, vinte e três de outubro, 1º de maio, dia 30, dia quinze.
- Dates with a time, ISO style: 2026-10-15T14:30, 2026-10-15 14:30:00,
  2026-10-15T14:30:00-03:00. With an offset, the moment is the one it names.
- Periods: esta semana, semana que vem, fim de semana, no meio da semana, este
  mês, no início do mês, fim do mês, primeira quinzena de outubro, em outubro,
  março de 2027, dez/2027, no próximo trimestre, primeiro semestre, ano que
  vem, fim do ano. A period under way runs from today: "no segundo semestre"
  said in September starts that day.
- Holidays: no natal, véspera de natal, no ano novo, na páscoa, no carnaval,
  sexta-feira santa, corpus christi, dia de finados, dia das mães, dia dos pais.
- Counted from another date: dois dias antes do natal, véspera do ano novo,
  uma semana depois do dia 10.
- Business days: em 5 dias úteis, no próximo dia útil, primeiro dia útil do
  mês. Weekends, national holidays, Carnival Monday and Tuesday and Corpus
  Christi are skipped, as the banks do.

## Times

- Clock times: às 9, 14h, 9h30, 10:30, 15:30h, 9am, 7:30 pm, às 7 e meia, às
  sete da noite, às vinte e duas horas, 3 da tarde, quinze para as oito,
  meio-dia e meia.
- Parts of the day and moments: de manhã, à tarde, à noite, de madrugada, cedo,
  no almoço, na janta, depois do trabalho, antes de dormir.
- Whole parts of the day: a manhã toda (6:00 to 12:00), a tarde inteira, toda a
  noite, a madrugada toda. The whole day, "o dia todo" or "dia inteiro", sets
  ``ChronoPT/Match/isAllDay`` and needs a day.
- From now: daqui 2 horas, em meia hora, daqui a pouco (30 minutes), mais
  tarde (2 hours).
- Ranges: das 14h às 16h, 14h às 16h, 10h-11h, entre 10 e 11h, de segunda a
  sexta, do dia 10 ao dia 15, de 10 a 15 de outubro.

## Repeating and past dates

- Repeating: todo dia, toda terça, às segundas e quartas, todo dia 5, a cada
  15 dias, de 8 em 8 horas. See ``ChronoPT/Recurrence``.
- Past, with ``ChronoPT/Options/allowsPast``: ontem, sexta passada, semana
  passada, há 2 dias, 3 dias atrás.

## Ambiguous text

- A time with no day is today, or tomorrow if that time has passed.
- A weekday is the next one, not counting today.
- "às 7" is 19:00, and ``ChronoPT/PartialDate/alternative`` holds 7:00. A part
  of the day or a written hour settles it.
- Ordinals are not weekdays: "segunda via do boleto" is not a date. Monday to
  Friday need a hint: a preposition, "que vem", a time, a date or a range.
- A weekday with a bare number is that day only when the two agree: "sexta,
  25" is the 25th when it is a Friday. Otherwise, or when the number counts
  something ("sexta 25 pessoas"), the number is not a day.
- A duration is not a time: "estudar por 2 horas", "trabalhar 8h por dia".
- A holiday name with another meaning needs a preposition: "voo para Natal" is
  the city.
- "ter" is the verb, never Tuesday, and "agora" alone is not a date.
