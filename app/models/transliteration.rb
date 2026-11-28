# Latin forms of names written in Greek, for a site in English, following
# ELOT 743 / ISO 843 (the system on Greek road signs and passports):
# "Ξενοδοχείο Ήλιος" → "Xenodocheio Ilios". Used only when OSM has no English
# or international name.
module Transliteration
  # Pairs first, so "ου" is "ou" rather than "oy".
  GREEK_PAIRS = {
    "ου" => "ou", "αυ" => "av", "ευ" => "ev", "ηυ" => "iv",
    "γγ" => "ng", "γκ" => "gk", "γξ" => "nx", "γχ" => "nch",
    "μπ" => "mp", "ντ" => "nt"
  }.freeze

  GREEK_LETTERS = {
    "α" => "a", "β" => "v", "γ" => "g", "δ" => "d", "ε" => "e", "ζ" => "z", "η" => "i", "θ" => "th",
    "ι" => "i", "κ" => "k", "λ" => "l", "μ" => "m", "ν" => "n", "ξ" => "x", "ο" => "o", "π" => "p",
    "ρ" => "r", "σ" => "s", "ς" => "s", "τ" => "t", "υ" => "y", "φ" => "f", "χ" => "ch", "ψ" => "ps",
    "ω" => "o"
  }.freeze

  GREEK = /\p{Greek}/

  module_function

  def greek?(text)
    text.to_s.match?(GREEK)
  end

  # Latin text, with the case of each word kept (first letter capital when
  # the Greek one was).
  def from_greek(text)
    # Drop accents and diaereses: "Ήλιος" → "Ηλιος".
    plain = text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").unicode_normalize(:nfc)
    plain.split(/(\s+)/).map { |word| word.match?(GREEK) ? word_from_greek(word) : word }.join
  end

  def word_from_greek(word)
    lower = word.downcase
    latin = +""
    index = 0
    while index < lower.length
      pair = GREEK_PAIRS[lower[index, 2]]
      if pair
        latin << pair
        index += 2
      else
        latin << GREEK_LETTERS.fetch(lower[index], lower[index])
        index += 1
      end
    end
    word[0] == word[0].downcase ? latin : latin.capitalize
  end
  private_class_method :word_from_greek
end
