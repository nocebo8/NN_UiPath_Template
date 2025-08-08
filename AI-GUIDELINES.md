# Zasady dla AI (Cursor/GPT-5) — UiPath ReFramework

1) NIE edytuj plików: Main.xaml, Framework/** (Init*, Process*, End*) — chyba że proszę o „minimalny patch" (unified diff).
2) Nowe funkcje dodawaj jako osobne XAML-e w Workflows/** i podpinaj je przez "Invoke Workflow File".
3) Nie zmieniaj namespace'ów, prefiksów i atrybutów XML (x:*, sap2010:*, mc:Ignorable, ui:*).
4) Jeśli dotykasz krytycznych XAML — zwróć zmiany jako patch (format unified diff), bez przepisywania całych plików.
5) Logikę programistyczną (walidacje/parsowanie/algorytm) preferuj w C# (Invoke Code) albo w osobnej bibliotece .NET.
6) Dodawaj komentarze do XAML w `sap2010:Annotation.AnnotationText`.
- **Prefer pipeline orchestration for chained CI tasks**: kiedy wynik jednego joba (run id, artefakty, logi) jest potrzebny jako wejście do kolejnego joba, używaj jednego workflow z wieloma jobami i artefaktami/outputs zamiast ręcznego przekazywania run_id. Ułatwia to debug, automatyzację i bezpieczeństwo.
- **Prefer pipeline orchestration for chained CI tasks**: kiedy wynik jednego joba (run id, artefakty, logi) jest potrzebny jako wejście do kolejnego joba, używaj jednego workflow z wieloma jobami i artefaktami/outputs zamiast ręcznego przekazywania run_id. Ułatwia to debug, automatyzację i bezpieczeństwo.
