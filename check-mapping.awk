# Input: objdump -t followed by objdump -d --disassemble=SYMBOL.
function hexnumber(S,    I, N, D) {
  N = 0
  S = tolower(S)
  for (I = 1; I <= length(S); ++I) {
    D = index("0123456789abcdef", substr(S, I, 1)) - 1
    if (D < 0) return -1
    N = N * 16 + D
  }
  return N
}
FNR == NR {
  if ($NF == symbol)
    for (I = 1; I < NF; ++I)
      if ($I == ".text" && $(I + 1) ~ /^[0-9a-fA-F]+$/) {
        Size = hexnumber($(I + 1))
        ++Found
      }
  next
}
$1 ~ /^[0-9a-fA-F]+:$/ && $2 ~ /^[0-9a-fA-F]+$/ && NF >= 3 {
  if (length($2) != 4 && length($2) != 8) Bad = 1
  ++Instructions
  DecodedBytes += length($2) / 2
  if ($3 == "vsetvli" || $3 == "vsetivli" || $3 == "vsetvl") ++Setups
}
END {
  OK = Found == 1 && !Bad && Instructions == expected_instructions &&
       Size == expected_bytes && DecodedBytes == Size && Setups == expected_setups
  print pipeline "," label "," consumer "," symbol "," Instructions "," Size "," \
        DecodedBytes "," Setups "," expected_instructions "," expected_bytes "," \
        expected_setups "," (OK ? "PASS" : "UNEXPECTED_MAPPING")
  if (!OK) exit 1
}
