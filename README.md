# CareLoop Clinics — No-Show Guard

**Repository:** <paste your GitHub link here>

From raw bookings to a risk model and an AI-assisted follow-up review.
Capstone project — Masai × E&ICT Academy, IIT Roorkee.

**Business question:** Which appointments are most likely to be missed, why do patients miss them, and what should CareLoop do first?

## Summary (one finding per Part)
1. **Part 1 — Cleaning:** 1,020 raw bookings became 990 clean ones (20 duplicates, 6 unreadable dates and 4 blank statuses removed); 218 of them (22.0%) were no-shows.
2. **Part 2 — SQL:** booking far ahead raises the no-show rate: 16.2% for 1–7 days ahead, 30.0% for 15–30 days and 60.5% for 31+ days.
3. **Part 3 — ML:** logistic regression ranks risk best (test ROC-AUC 0.789); at a 0.35 threshold it flags 49 of 198 test bookings and catches 57% of no-shows.
4. **Part 4 — GenAI:** Gemini classified all 9 non-blank notes into allowed reasons; both patients who forgot (2 of 2) had not been sent a reminder.

## Recommendation
CareLoop should first make sure every booking gets a reminder, and use the model each evening to phone the riskiest bookings.
Bookings made far in advance are missed most often: the no-show rate climbs from 16.2% (1–7 days ahead) to 30.0% (15–30 days)
and 60.5% (31+ days). In the fitted model, holding the other features constant, a reminder goes with about 69% lower odds of a
no-show (odds × 0.31), and in the call-centre notes both patients who forgot had received no reminder (2 of 2). At a 0.35
threshold the model flags about 49 of 198 bookings (one in four) and catches 57% of no-shows, so the front desk can focus its
calls. Hadapsar Care Centre (27.3%) and Gomti Nagar Care Point (33.3%, though only 90 appointments) are the clinics to start with.

## Model choice
**Logistic regression, threshold 0.35.** It had the highest 5-fold cross-validated ROC-AUC on the training set (0.774, against
0.767 for the tuned random forest, 0.747 for the random forest and 0.678 for the depth-3 tree), so it was chosen without touching
the test set. The threshold was also chosen on out-of-fold training probabilities: 0.35 gave F1 0.49 and recall 0.47, against
F1 0.35 and recall 0.25 at 0.5. Recall matters here because a missed warning costs an empty doctor slot, while an extra call
costs about a minute. Tested once on the test set: ROC-AUC 0.789, precision 0.57, recall 0.57, 49 of 198 flagged.
It is also easy to explain: each coefficient shows whether a feature raises or lowers the risk.

## Limitations
1. The 10 analysed notes are an illustration; they cannot show the real reasons for no-shows across all clinics.
2. The cleaning statistics (medians, quartiles and outlier fences) were calculated on all 990 rows before the train/test split, so the test rows had a small indirect influence on the cleaning.
3. The data are observational, so the link between reminders and fewer no-shows is an association, not proof that reminders cause it.

## Files
| File | What it is |
|---|---|
| `data/` | The three original input files (unchanged) |
| `01_ingest_clean.ipynb` | Part 1: reading, cleaning, NumPy summary, weather API, export and SQL script (plus the Task 2.2 pandas check) |
| `rejected_rows.json` | 32 rows that failed type conversion in Task 1.1 |
| `appointments_clean.csv` | Clean table: 990 rows × 16 columns |
| `clinics_enriched.csv` | 8 clinics plus temperature from Open-Meteo |
| `load_data.sql` | 998 INSERT statements (8 clinics first, then 990 appointments) |
| `02_queries.sql` | Part 2: database build, checks, duplicate-key test, Tasks 2.2–2.5 |
| `03_model.ipynb` | Part 3: models, cross-validation, threshold choice, test evaluation |
| `test_risk_scores.csv` | Risk score and flag for the 198 test bookings |
| `04_genai.ipynb` | Part 4: Gemini + Pydantic (no API key inside) |
| `notes_analysed.csv` | The first 10 call-centre notes with structured reasons |

## How to run
1. **Part 1:** open `01_ingest_clean.ipynb` in Google Colab, upload the three files from `data/` into a `data` folder, and run all cells.
2. **Part 2:** in MySQL Workbench (MySQL 8), run the Task 2.1 block of `02_queries.sql`, then `load_data.sql`, then the remaining queries.
3. **Part 3:** open `03_model.ipynb` in Colab, upload `appointments_clean.csv`, and run all cells.
4. **Part 4:** get a free Gemini API key at aistudio.google.com/api-keys (no card needed). Open `04_genai.ipynb` in Colab, upload `data/followup_notes.csv` and `appointments_clean.csv`, run all cells, and paste the key when asked. The key is typed at run time and is never saved in any file. Part 4 needs about 15 API calls.

**Tools:** Python in Google Colab (pandas, NumPy, scikit-learn, requests, Pydantic, google-genai) · MySQL 8 · Gemini `gemini-3.5-flash` (free tier) · Open-Meteo (free, no key).
Temperatures in `clinics_enriched.csv` were fetched on 17 Nov 2026 and change daily.