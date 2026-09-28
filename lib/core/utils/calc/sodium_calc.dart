/// Salt and sodium are different quantities: EU/UK labels list salt, which
/// is sodium × 2.5 (Regulation (EU) No 1169/2011, Annex XIV). The app stores
/// sodium in mg; salt is converted on the way in and shown as a derived value.
class SodiumCalc {
  static const saltPerSodium = 2.5;

  static double saltGToSodiumMg(double saltG) => saltG / saltPerSodium * 1000;

  static double sodiumMgToSaltG(double sodiumMg) =>
      sodiumMg / 1000 * saltPerSodium;
}
