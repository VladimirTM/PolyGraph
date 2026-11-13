import pytest

from polygraph.extract.display import display_brand, display_form, display_specialty, display_strength


@pytest.mark.parametrize(
    ("label", "key", "strength", "form", "expected"),
    [
        ("SINTROM 4 mg", "sintrom", "4mg", "COMPR.", ("Sintrom", "4 mg", "comprimate")),
        ("NUROFEN 400 mg", "nurofen", "400mg", "comprimate filmate", ("Nurofen", "400 mg", "comprimate filmate")),
        ("FROMILID 500 mg", "fromilid", "500mg", "COMPR. FILM.", ("Fromilid", "500 mg", "comprimate filmate")),
        ("EUTHYROX 75 µg", "euthyrox", "75 µg", "COMPR.", ("Euthyrox", "75 mcg", "comprimate")),
        ("EUTHYROX 100µg", "euthyrox", "100µg", "COMPR.", ("Euthyrox", "100 mcg", "comprimate")),
        (
            "SIMVASTATIN TERAPIA 40 mg",
            "simvastatin terapia",
            "40mg",
            "COMPR. FILM.",
            ("Simvastatin Terapia", "40 mg", "comprimate filmate"),
        ),
        ("AMLODIPINA ARENA 10 mg", "amlodipina arena", "10mg", "COMPR.", ("Amlodipina Arena", "10 mg", "comprimate")),
        (
            "OMEPRAZOL ZENTIVA 20mg",
            "omeprazol zentiva",
            "20mg",
            "CAPS. GASTROREZ.",
            ("Omeprazol Zentiva", "20 mg", "capsule gastrorezistente"),
        ),
        (
            "AMITRIPTILINA ARENA 25 mg",
            "amitriptilina arena",
            "25mg",
            "COMPR. FILM.",
            ("Amitriptilina Arena", "25 mg", "comprimate filmate"),
        ),
        (
            "CALCIU + VITAMINA D3 (după cutia reală)",
            "calciu + vitamina d3",
            None,
            "comprimate",
            ("Calciu + Vitamina D3", None, "comprimate"),
        ),
    ],
)
def test_catalog_display(label, key, strength, form, expected):
    assert (display_brand(label, key), display_strength(strength), display_form(form)) == expected


def test_display_variants():
    assert display_brand("SINTROM 4 mg", "sintrom", ["Sintrom"]) == "Sintrom"
    assert display_brand("ORL D3", "orl d3") == "ORL D3"
    assert display_brand("AMLODIPINA ARENA 10 mg", "amlodipina arena", ["Amlodipină Arena"]) == "Amlodipină Arena"
    assert display_strength("400mg/880iu") == "400 mg/880 UI"
    assert display_strength("75ug") == "75 mcg"
    assert display_form("CAPS.") == "capsule"
    assert display_form("SOL. INJ.") == "soluție injectabilă"
    assert display_form("FORMĂ NECUNOSCUTĂ") == "formă necunoscută"
    assert display_specialty("orl") == "ORL"
    assert display_specialty("MEDICINA DE FAMILIE") == "medicină de familie"
    assert display_specialty("CARDIOLOGIE") == "cardiologie"
