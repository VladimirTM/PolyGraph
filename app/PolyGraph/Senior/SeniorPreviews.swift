#if DEBUG
import SwiftUI

/// Date fixe pentru Xcode Previews (o parte din pacientul demo), fără server.
enum SeniorPreviewData {
    static let patientJSON = #"""
{"id": "pat_demo", "name": "Maria", "birth_year": 1948, "caregiver_name": "Ana", "anchors": {"wake": "07:00", "breakfast": "08:00", "lunch": "13:00", "dinner": "19:00", "bed": "22:30"}}
"""#

    static let medsJSON = #"""
[{"id": "med_02", "source": "photo_box", "product": {"brand": "Nurofen", "strength_text": "400 mg", "form": "comprimate filmate", "gtin": null, "pack_size": 24, "expiry": null, "batch": null}, "substances": [{"dci": "IBUPROFENUM", "inn": "ibuprofen", "atc": "M01AE01", "strength_mg": 400.0}], "dosage": {"raw": "1-0-1, după masă", "pattern": {"morning": 1, "noon": 0, "evening": 1, "bedtime": 0}, "as_needed": false, "with_food": "with_meal"}, "prescriber": {"name": null, "specialty": null}, "start_date": "2026-09-15", "end_date": null, "photo_url": "/media/med_02.jpg", "match": {"method": "exact_brand", "confidence": 0.97, "needs_review": false}}, {"id": "med_04", "source": "photo_box", "product": {"brand": "Amlodipină", "strength_text": "10 mg", "form": "comprimate", "gtin": null, "pack_size": 30, "expiry": null, "batch": null}, "substances": [{"dci": "AMLODIPINUM", "inn": "amlodipine", "atc": "C08CA01", "strength_mg": 10.0}], "dosage": {"raw": "1-0-0", "pattern": {"morning": 1, "noon": 0, "evening": 0, "bedtime": 0}, "as_needed": false, "with_food": "any"}, "prescriber": {"name": null, "specialty": "medicină de familie"}, "start_date": "2023-05-10", "end_date": null, "photo_url": "/media/med_04.jpg", "match": {"method": "exact_brand", "confidence": 0.97, "needs_review": false}}, {"id": "med_05", "source": "photo_box", "product": {"brand": "Euthyrox", "strength_text": "75 mcg", "form": "comprimate", "gtin": null, "pack_size": 100, "expiry": null, "batch": null}, "substances": [{"dci": "LEVOTHYROXINUM NATRIUM", "inn": "levothyroxine", "atc": "H03AA01", "strength_mg": 0.075}], "dosage": {"raw": "1 cp dimineața, pe stomacul gol", "pattern": {"morning": 1, "noon": 0, "evening": 0, "bedtime": 0}, "as_needed": false, "with_food": "empty_stomach"}, "prescriber": {"name": null, "specialty": "endocrinologie"}, "start_date": "2021-02-01", "end_date": null, "photo_url": "/media/med_05.jpg", "match": {"method": "exact_brand", "confidence": 0.97, "needs_review": false}}, {"id": "med_07", "source": "photo_box", "product": {"brand": "Omeprazol", "strength_text": "20 mg", "form": "capsule gastrorezistente", "gtin": null, "pack_size": 28, "expiry": null, "batch": null}, "substances": [{"dci": "OMEPRAZOLUM", "inn": "omeprazole", "atc": "A02BC01", "strength_mg": 20.0}], "dosage": {"raw": "1-0-0, înainte de masă", "pattern": {"morning": 1, "noon": 0, "evening": 0, "bedtime": 0}, "as_needed": false, "with_food": "before_meal"}, "prescriber": {"name": null, "specialty": "gastroenterologie"}, "start_date": "2024-11-01", "end_date": null, "photo_url": "/media/med_07.jpg", "match": {"method": "exact_brand", "confidence": 0.97, "needs_review": false}}]
"""#

    static let scheduleJSON = #"""
{"date": "2026-11-14", "anchors": {"wake": "07:00", "breakfast": "08:00", "lunch": "13:00", "dinner": "19:00", "bed": "22:30"}, "moments": [{"time": "07:00", "label": "Imediat după trezire", "doses": [{"med_id": "med_05", "qty": 1, "instruction": "pe stomacul gol, cu jumătate de pahar cu apă", "reasons": ["Euthyrox se ia pe stomacul gol, cu cel puțin 30 de minute înainte de micul dejun (RCP Euthyrox)", "Singur, ca nimic să nu-i scadă absorbția"]}]}, {"time": "07:30", "label": "Cu o jumătate de oră înainte de micul dejun", "doses": [{"med_id": "med_07", "qty": 1, "instruction": "înainte de micul dejun, înghițită întreagă", "reasons": ["Omeprazolul se ia înainte de micul dejun (RCP omeprazol)"]}, {"med_id": "med_04", "qty": 1, "instruction": "cu un pahar cu apă", "reasons": ["Amlodipina se ia o dată pe zi, dimineața"]}]}, {"time": "08:00", "label": "La micul dejun", "doses": [{"med_id": "med_02", "qty": 1, "instruction": "la masă, cu un pahar cu apă", "reasons": ["Ibuprofenul se ia la masă, ca să protejeze stomacul"]}]}], "unsatisfied": [], "solver": {"moments_count": 3, "version": "fixture-p0"}}
"""#

    static func store() -> AppStore {
        // 07:10 în ziua programului: momentul de după trezire, cu butoanele active
        var debug = DebugEnvironment()
        debug.now = SeniorDay.scheduledAt(day: "2026-11-14", time: "07:10")
        let store = AppStore(
            settings: AppSettings(defaults: UserDefaults(suiteName: "pg.preview") ?? .standard), debug: debug)
        let decoder = JSONCoding.decoder
        let patient = try? decoder.decode(Patient.self, from: Data(patientJSON.utf8))
        let meds = (try? decoder.decode([MedicationItem].self, from: Data(medsJSON.utf8))) ?? []
        let schedule = try? decoder.decode(Schedule.self, from: Data(scheduleJSON.utf8))
        store.usePreviewData(patient: patient, meds: meds, schedule: schedule)
        return store
    }
}

private struct NowPreview: View {
    let size: DynamicTypeSize
    @State private var store = SeniorPreviewData.store()

    var body: some View {
        NavigationStack {
            NowView()
        }
        .environment(store)
        .dynamicTypeSize(size)
    }
}

#Preview("Acum · large") {
    NowPreview(size: .large)
}

#Preview("Acum · xxxLarge") {
    NowPreview(size: .xxxLarge)
}

#Preview("Acum · accessibility3") {
    NowPreview(size: .accessibility3)
}

#Preview("Acum · accessibility3 · dark") {
    NowPreview(size: .accessibility3)
        .preferredColorScheme(.dark)
}

#Preview("Acum · large · dark") {
    NowPreview(size: .large)
        .preferredColorScheme(.dark)
}

#Preview("Ziua de azi · accessibility3") {
    NavigationStack {
        DayView(onOpenMoment: { _ in })
    }
    .environment(SeniorPreviewData.store())
    .dynamicTypeSize(.accessibility3)
}
#endif
