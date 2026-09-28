class EvidenceSource {
  final String id;
  final String title;
  final String url;
  final String context;
  const EvidenceSource(this.id, this.title, this.url, this.context);
}

const evidenceReviewed = '28 September 2026';
const evidenceSources = [
  EvidenceSource(
      'intergrowth-study',
      'INTERGROWTH-21st • Original cohort study',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC4770850/',
      'Cheikh Ismail et al. (2016), doi:10.1136/bmj.i555. Prospective study; 3,097 eligible women with normal early-pregnancy BMI. Population centiles do not define individual treatment targets.'),
  EvidenceSource(
      'intergrowth',
      'INTERGROWTH-21st • Published weight-gain centiles',
      'https://media.tghn.org/medialibrary/2017/05/GROW_GWG-nw-ct_Table.pdf',
      'Cheikh Ismail et al., BMJ 2016;352:i555. Study comparison for healthy singleton pregnancies with first-trimester BMI 18.5–24.9. Gain is relative to an early-pregnancy reading, not pre-pregnancy weight. Published weeks 15–40; no extrapolation.'),
  EvidenceSource(
      'acog-energy',
      'ACOG • Energy during pregnancy',
      'https://www.acog.org/womens-health/experts-and-stories/ask-acog/how-much-weight-should-i-gain-during-pregnancy',
      'For singletons: 340 extra kcal/day in trimester 2 and about 450 in trimester 3, above pre-pregnancy maintenance. Individual needs vary.'),
  EvidenceSource(
      'macro-dri',
      'National Academies • Pregnancy macronutrient DRIs',
      'https://www.ncbi.nlm.nih.gov/books/NBK545442/',
      'Adult pregnancy: carbohydrate RDA 175 g/day, protein RDA 71 g/day, fiber AI 28 g/day. Adult fat range 20–35% of energy. The app uses a practical 50/20/30 split when an energy plan is supplied; this is not a uniquely recommended pregnancy ratio.'),
  EvidenceSource(
      'nih',
      'NIH • Nutrition during pregnancy',
      'https://ods.od.nih.gov/factsheets/Pregnancy-HealthProfessional/',
      'Evidence review and US Dietary Reference Intakes. RDA means Recommended Dietary Allowance; AI means Adequate Intake, used when evidence is insufficient to set an RDA.'),
  EvidenceSource(
      'iom',
      'National Academies • Weight gain guidelines (2009)',
      'https://nap.nationalacademies.org/resource/12584/Resource-Page---Weight-Gain-During-Pregnancy.pdf',
      'Consensus guidance based largely on observational evidence. Population ranges are not diagnostic boundaries for an individual pregnancy.'),
  EvidenceSource(
      'cdc',
      'CDC • Pregnancy weight gain',
      'https://www.cdc.gov/maternal-infant-health/pregnancy-weight/index.html',
      'Current public-health guidance uses pre-pregnancy BMI and pregnancy type. Includes official trackers for singletons and twins.'),
  EvidenceSource(
      'canada',
      'Health Canada • Pregnancy weight gain',
      'https://sante.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/prenatal-nutrition/pregnancy-weight-gain-calculator.html?wbdisable=true',
      'Metric total-gain ranges from the Institute of Medicine guidance.'),
  EvidenceSource(
      'nhs',
      'NHS • Foods to avoid in pregnancy',
      'https://www.nhs.uk/pregnancy/keeping-well/foods-to-avoid/',
      'UK guidance on caffeine and food preparation. Food-safety details can differ by country.'),
  EvidenceSource(
      'fda',
      'FDA/EPA • Choosing fish',
      'https://www.fda.gov/food/consumers/advice-about-eating-fish',
      'US guidance on lower-mercury seafood and serving frequency.'),
  EvidenceSource(
      'swiss',
      'Swiss FSVO • Pregnancy and breastfeeding',
      'https://www.blv.admin.ch/en/recommendations-for-those-who-are-pregnant-or-breastfeeding',
      'Local guidance to discuss with your maternity team if you receive care in Switzerland.'),
];

class PregnancyNutrient {
  final String name;
  final String amount;
  final String kind;
  final String foods;
  final String note;
  const PregnancyNutrient(
      this.name, this.amount, this.kind, this.foods, this.note);
}

// Adult (19–50 y) pregnancy DRIs; amounts are total daily intake, NOT doses
// to add as supplements. No inference of adequacy from incomplete food logs.
const pregnancyNutrients = [
  PregnancyNutrient(
      'Folate',
      '600 µg DFE',
      'RDA',
      'Beans, leafy greens and fortified grains.',
      'DFE means dietary folate equivalents; this is not a 600 µg folic-acid prescription.'),
  PregnancyNutrient(
      'Iron',
      '27 mg',
      'RDA',
      'Meat, beans and iron-fortified cereals.',
      'Supplement decisions depend on your prenatal plan and any blood-test results.'),
  PregnancyNutrient(
      'Calcium',
      '1,000 mg',
      'RDA',
      'Pasteurized dairy, calcium-set tofu and fortified plant drinks.',
      'Check labels: fortification varies.'),
  PregnancyNutrient(
      'Iodine',
      '220 µg',
      'RDA',
      'Dairy, eggs, seafood and iodized salt.',
      'Do not increase salt intake to meet this value; discuss supplements, especially with thyroid disease.'),
  PregnancyNutrient('Choline', '450 mg', 'AI', 'Eggs, soybeans, meat and fish.',
      'An AI has less certainty than an RDA; many prenatal supplements contain little choline.'),
  PregnancyNutrient(
      'Vitamin D',
      '15 µg / 600 IU',
      'RDA',
      'Oily fish and fortified foods.',
      'This is total intake. Regional supplement recommendations differ.'),
  PregnancyNutrient(
      'Vitamin B12',
      '2.6 µg',
      'RDA',
      'Animal foods and B12-fortified foods.',
      'A vegan diet needs a reliable B12 source; discuss your plan with your care team.'),
];
