# raw.csv summary: retain all observations and use sample standard deviation.
BEGIN { FS = ","; OFS = "," }
function sort_values(A, N,    I, J, V) {
  for (I = 2; I <= N; ++I) {
    V = A[I]
    J = I - 1
    while (J > 0 && A[J] > V) { A[J + 1] = A[J]; --J }
    A[J + 1] = V
  }
}
function median(A, N) {
  return N % 2 ? A[(N + 1) / 2] : (A[N / 2] + A[N / 2 + 1]) / 2
}
NR == 1 { next }
{
  Key = $1 OFS $2 OFS $5
  N[Key]++
  Values[Key SUBSEP N[Key]] = $9 + 0
  Sum[Key] += $9
}
END {
  print "pipeline,consumer,label,n,mean_ns,median_ns,sample_sd_ns,mad_ns,min_ns,max_ns"
  for (Key in N) {
    for (I in Ordered) delete Ordered[I]
    for (I in Deviations) delete Deviations[I]
    Mean = Sum[Key] / N[Key]
    Squares = 0
    for (I = 1; I <= N[Key]; ++I) {
      Ordered[I] = Values[Key SUBSEP I]
      D = Ordered[I] - Mean
      Squares += D * D
    }
    sort_values(Ordered, N[Key])
    Median = median(Ordered, N[Key])
    SD = N[Key] > 1 ? sqrt(Squares / (N[Key] - 1)) : 0
    for (I = 1; I <= N[Key]; ++I) {
      D = Ordered[I] - Median
      Deviations[I] = D < 0 ? -D : D
    }
    sort_values(Deviations, N[Key])
    printf "%s,%d,%.3f,%.3f,%.3f,%.3f,%.0f,%.0f\n", Key, N[Key], Mean,
           Median, SD, median(Deviations, N[Key]), Ordered[1], Ordered[N[Key]]
  }
}
