# EmpiricalCDFs.jl
### Empirical cumulative distribution functions

Linux, OSX: [![Build Status](https://travis-ci.org/jlapeyre/EmpiricalCDFs.jl.svg?branch=master)](https://travis-ci.org/jlapeyre/EmpiricalCDFs.jl)
&nbsp;
Windows: [![Build Status](https://ci.appveyor.com/api/projects/status/github/jlapeyre/EmpiricalCDFs.jl?branch=master&svg=true)](https://ci.appveyor.com/project/jlapeyre/empiricalcdfs-jl)
&nbsp; &nbsp; &nbsp;
[![Coverage Status](https://coveralls.io/repos/jlapeyre/EmpiricalCDFs.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/jlapeyre/EmpiricalCDFs.jl?branch=master)
[![codecov.io](http://codecov.io/github/jlapeyre/EmpiricalCDFs.jl/coverage.svg?branch=master)](http://codecov.io/github/jlapeyre/EmpiricalCDFs.jl?branch=master)

Provides [empirical cumulative distribution functions (CDFs)](https://en.wikipedia.org/wiki/Empirical_distribution_function)
(or "empirical distribution functions" as they are know to probabalists). The last version to support Julia v0.5 is v0.0.2.

*EmpiricalCDFs* implements empirical CDFs; building, evaluating, random sampling, evaluating the inverse, etc.
It is useful especially for examining the
tail of the CDF obtained from streaming a large number of data, more than can be stored in memory.
For this purpose, you specify a lower cutoff; data points below this value will be silently rejected, but the
resulting CDF will still be properly normalized. One of the main features of *EmpiricalCDFs*
that is absent in `StatsBase.ecdf` is this ability to process and filter data online.

```julia
 cdf = EmpiricalCDF()
 push!(cdf,x)
 ...
 print(io,cdf)

# reject points `x < xmin` to save memory.
 cdf = EmpiricalCDF(xmin)
```

`EmpiricalCDFs` is not a registered package.

### Warning about sorting

Before using the cdf, you must call `sort!(cdf)`. For efficiency data is not sorted as it is inserted.
The exception is `print`, which does sort the cdf before printing.

### Functions

`push!(cdf,x)` add datum `x` to `cdf`.

`append!(cdf,a)` append data from iterator `a` to the cdf.

`sort!(cdf)` The data must be sorted before calling `cdf(x)`.

`cdf(x)` evaluate `cdf` at the value `x`.

`rand(cdf)`  return a sample from the empirical probability distribution associated with `cdf`.

`getinverse(cdf::EmpiricalCDF,c)` return the functional inverse of `cdf` at the value `c`.

Several existing methods on `AbstractEmpiricalCDF` simply call
the same funciton on the underlying data. These are:
`length`, `minimum`, `maximum`, `mean`, `std`,
`quantile`.

The printing functions are currently skewed to my needs.
`logprint(io,cdf)` or `print(io,cdf)` print the cdf.
By default `2000` log-spaced points of `cdf` are printed, unless any samples are `< = 0`, in which case
they are linearly spaced. Six fields are printed for each coordinate `x`:
`log10(x)`, `log10(1-cdf_val)`, `log10(cdf_val)`, `x`, `cdf_val`, `1-cdf_val`.

`linprint(io,cdf)` print linearly spaced points.

See the doc strings for more information.

### `CDFfile` and io

I found available serialization choices to be too slow. So, very simple, very fast, binary
storage and retrieval is provided. By now, or in the future, there will certainly be packages
that provide a sufficient or better replacement.

The type `CDFfile` supports reading and writing `AbstractEmpiricalCDF` objects in binary format. Most functions
that operate on `AbstractEmpiricalCDF` also work with `CDFfile`, with the call being passed to the `cdf` field.

`saves(fn::String, cdf, header="")` writes a binary file. See documentation for `readcdf`.

### Maximum likelihood estimate of a power law

Maximum likelihood is no longer in this package . It has been moved to the package `MLEPower`.

### Comparison with `ecdf`

This package differs from the  [`ecdf` function](https://statsbasejl.readthedocs.io/en/latest/empirical.html#ecdf)
from [`StatsBase.jl`](https://github.com/JuliaStats/StatsBase.jl).

- `ecdf` takes a sorted vector as input and returns a function that looks up the value of the
   CDF. An instance of `EmpiricalCDF`, `cdf`, both stores data, eg via `push!(cdf,x)`, and looks
 up the value of the CDF via `cdf(x)`.
- When computing the CDF at an array of values, `ecdf`, sorts the input and uses an algorithm that scans the
  data. Instead, `EmpiricalCDFs` does a binary search for each element of an input vector. Tests showed that this
  is typically not slower. If the CDF stores a large number of points relative to the size of the input vector,
  the second method, the one used by `EmpiricalCDFs` is faster.

<!-- LocalWords:  EmpiricalCDFs jl OSX codecov io CDFs probabalists CDF eg -->
<!-- LocalWords:  julia cdf EmpiricalCDF xmin logprint linprint getinverse -->
<!-- LocalWords:  quantile CDFfile AbstractEmpiricalCDF readcdf mle mleKS -->
<!-- LocalWords:  scanmle KSstatistic AbstractArrays ecdf StatsBase -->
