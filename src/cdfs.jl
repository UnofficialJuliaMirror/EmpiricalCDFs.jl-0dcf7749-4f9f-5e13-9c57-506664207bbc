using Compat

"""
    AbstractEmpiricalCDF

Concrete types are `EmpiricalCDF` and `EmpiricalCDFHi`.
"""
abstract type AbstractEmpiricalCDF end


struct EmpiricalCDF{T <: Real} <: AbstractEmpiricalCDF
    xdata::Vector{T}
end

"""
    data(cdf::AbstractEmpiricalCDF)

return the array holding samples for `cdf`.
"""
data(cdf::AbstractEmpiricalCDF) = cdf.xdata

# Extend base functions
# TODO: Check that these are doing what we want!
# We should fix quantile
for f in ( :length, :minimum, :maximum, :extrema, :mean, :median, :std, :quantile )
    @eval begin
        Base.$(f)(cdf::AbstractEmpiricalCDF,args...) = $(f)(cdf.xdata,args...)
    end
end

# Same as above, but the return value is the cdf

@doc """
    sort!(cdf::AbstractEmpiricalCDF)

Sort the data collected in `cdf`. You must call `sort!` before using `cdf`.
""" sort!

for f in (:sort!,)
    @eval begin
        Base.$(f)(cdf::AbstractEmpiricalCDF,args...) = ($(f)(cdf.xdata,args...); cdf)
    end
end

getcdfindex(cdf::AbstractEmpiricalCDF, x::Real) = searchsortedlast(cdf.xdata, x)

# getindex is not implemented. It may be used for something in the future
#Base.getindex(cdf::AbstractEmpiricalCDF, x::Real) = _val_at_index(cdf, getcdfindex(cdf, x))

# With several tests, this is about the same speed or faster than the routine borrowed from StatsBase
function _getinds(cdf::AbstractEmpiricalCDF, v::AbstractArray{T}) where T <: Real
    r = Array{eltype(cdf.xdata)}(size(v)...)
    for (i,x) in enumerate(v)
        @inbounds r[i] = cdf(x)
    end
    r
end

(cdf::EmpiricalCDF)(x::Real) = _val_at_index(cdf, getcdfindex(cdf, x))

(cdf::EmpiricalCDF)(v::AbstractArray) = _getinds(cdf,v)

Base.getindex(cdf::AbstractEmpiricalCDF, v::AbstractArray{T}) where {T <: Real} = _getinds(cdf,v)

"""
    EmpiricalCDF()

Return an empirical CDF. After inserting elements with `push!` or
`append!`, and before being accessed using any of the functions below, the CDF must be sorted with `sort!`.

`EmpiricalCDF` and `EmpiricalCDFHi` are callable objects.

```julia-repl
julia> cdf = EmpiricalCDF();
julia> append!(cdf,randn(10^6));
julia> sort!(cdf);
julia> cdf(0.0)
0.499876
julia> cdf(1.0)
0.840944
julia> cdf(-1.0)
0.158494
```
In this example, we collected \$10^6\$ samples from the unit normal distribution. About half of the
samples are greater than zero. Approximately the same mass is between zero and one as is between
zero and minus one.
"""
EmpiricalCDF() = EmpiricalCDF(Array{Float64}(undef,0))

"""
    EmpiricalCDFHi{T <: Real} <: AbstractEmpiricalCDF

Empirical CDF with lower cutoff. That is, keep only the tail.
"""
struct EmpiricalCDFHi{T <: Real} <: AbstractEmpiricalCDF
    lowreject::T  # reject counts smaller than this
    rejectcounts::Array{Int,1}  # how many rejections have we done
    xdata::Array{T,1}  # death times
end

(cdf::EmpiricalCDFHi)(x::Real) = _val_at_index(cdf, getcdfindex(cdf, x))

"""
    EmpiricalCDFHi(lowreject::Real)

Return a CDF that does not store samples whose values are less than `lowreject`. The
sorted CDF will still be properly normalized.
"""
function EmpiricalCDFHi(lowreject::Real)
    cdf = EmpiricalCDFHi(lowreject, Array{Int}(undef,1), Array{typeof(lowreject)}(undef,0))
    cdf.rejectcounts[1] = 0
    cdf
end

"""
    EmpiricalCDF(lowreject::Real)

If `lowereject` is finite return `EmpiricalCDFHi(lowreject)`. Otherwise
return `EmpiricalCDF()`.
"""
function EmpiricalCDF(lowreject::Real)
    if isfinite(lowreject)
        EmpiricalCDFHi(lowreject)
    else
        EmpiricalCDF()
    end
end

"""
    counts(cdf::AbstractEmpiricalCDF)

return the number of counts added to `cdf`. This includes counts
that may have been discarded because they are below of the cutoff.
"""
counts(cdf::AbstractEmpiricalCDF) = _total_counts(cdf)

# Number of points accepted plus number of points rejected
_total_counts(cdf::EmpiricalCDF) = length(cdf.xdata)
_total_counts(cdf::EmpiricalCDFHi) = length(cdf.xdata) + _rejectcounts(cdf)

# Value of the cdf corresponding to index i
_val_at_index(cdf::EmpiricalCDF, i) =  i/_total_counts(cdf)
_val_at_index(cdf::EmpiricalCDFHi, i) =  (i+ _rejectcounts(cdf) )/_total_counts(cdf)

_increment_rejectcounts(cdf::EmpiricalCDFHi) = cdf.rejectcounts[1] += 1

_rejectcounts(cdf::EmpiricalCDFHi) = cdf.rejectcounts[1]

"""
    push!(cdf::EmpiricalCDF,x::Real)

add the sample `x` to `cdf`.
"""
Base.push!(cdf::EmpiricalCDF,x::Real) = (push!(cdf.xdata,x) ; cdf)

function _push!(cdf::EmpiricalCDFHi,x::Real)
    if  x >= cdf.lowreject
        push!(cdf.xdata,x)
    else
        _increment_rejectcounts(cdf)
    end
end

function Base.push!(cdf::EmpiricalCDFHi, x::Real)
    if isinf(cdf.lowreject)
        push!(cdf.xdata,x)
    else
        _push!(cdf,x)
    end
    cdf
end

"""
    append!(cdf::EmpiricalCDF, a::AbstractArray)

add samples in `a` to `cdf`.
"""
Base.append!(cdf::EmpiricalCDF, a::AbstractArray) =  (append!(cdf.xdata,a); cdf)

function Base.append!(cdf::EmpiricalCDFHi, times)
    if  isinf(cdf.lowreject)
        append!(cdf.xdata,times)
    else
        for x in times
            _push!(cdf,x)
        end
    end
    cdf
end

function _inverse(cdf::EmpiricalCDF, x)
    ind = floor(Int, _total_counts(cdf)*x) + 1
    cdf.xdata[ind]
end

function _inverse(cdf::EmpiricalCDFHi, x)
    ind = floor(Int, _total_counts(cdf)*x) + 1 - _rejectcounts(cdf)
    cdf.xdata[ind]
end

"""
    rand(cdf::EmpiricalCDF)

Pick a random sample from the distribution represented by `cdf`.
"""
Base.rand(cdf::AbstractEmpiricalCDF) = _inverse(cdf,rand())

"""
    finv(cdf::AbstractEmpiricalCDF) --> Function

Return the functional inverse of `cdf`. `cdf` is a callable object.
`finv(cdf)` returns a function that captures `cdf` in a closure.

The following example begins with `cdf` containing \$10^6\$ samples from
the unit normal distribution.

```julia-repl
julia> icdf = finv(cdf);
julia> icdf(.5)
-0.00037235611091389375
julia> icdf(1.0-eps())
4.601393290425543
julia> maximum(cdf)
4.601393290425543
```
"""
function finv(cdf::EmpiricalCDF)
    function (c::Real)
        (c < 0 || c >= 1) && throw(DomainError())
        _inverse(cdf,c)
    end
end

function finv(cdf::EmpiricalCDFHi)
    function (c::Real)
        (c < cdf.lowreject || c >= 1) && throw(DomainError())
        _inverse(cdf,c)
    end
end

function Base.show(io::IO, cdf::EmpiricalCDF)
    print(io, string(typeof(cdf)))
    print(io, "(n=")
    print(io,length(cdf))
    print(io,')')
end

function Base.show(io::IO, cdf::EmpiricalCDFHi)
    print(io, string(typeof(cdf)))
    print(io, "(n=")
    print(io,length(cdf))
    print(io,",lowreject=")
    print(io,cdf.lowreject)
    print(io,')')
end

function Base.print(cdf::AbstractEmpiricalCDF,fn::String)
    io = open(fn,"w")
    print(io,cdf)
    close(io)
end

@doc """
    print(io::IO, cdf::AbstractEmpiricalCDF)

Call logprint(io,cdf)
""" print

Base.print(io::IO, cdf::AbstractEmpiricalCDF) = logprint(io,cdf)

"`linprint(io::IO ,cdf::AbstractEmpiricalCDF, n=2000)` print (not more than) `n` linearly spaced points after sorting the data."
linprint(io::IO, cdf::AbstractEmpiricalCDF,nprint_pts=2000; lastpt=false) = _printcdf(io,cdf,false,nprint_pts, lastpt=lastpt)
#linprint(io::IO, cdf::AbstractEmpiricalCDF, nprint_pts::Integer) = _printcdf(io,cdf,false, nprint_pts)

"`logprint(io::IO, cdf::EmpiricalCDF, n=2000)` print (not more than) `n` log spaced points after sorting the data."
logprint(io::IO, cdf::AbstractEmpiricalCDF, nprint_pts::Integer) = _printcdf(io,cdf,true, nprint_pts)
logprint(io::IO, cdf::AbstractEmpiricalCDF) = _printcdf(io,cdf,true, 2000)

Base.print(io::IO, cdf::AbstractEmpiricalCDF, nprint_pts::Integer) = logprint(io,cdf,nprint_pts)

Base.print(io::IO, cdf::AbstractEmpiricalCDF, prpts::AbstractArray) = _printcdf(io,cdf,prpts)

function Base.print(cdf::AbstractEmpiricalCDF, prpts::AbstractArray, fname::String)
    io = open(fname,"w")
    print(io,cdf,prpts)
    close(io)
end

"""
    linprint(fn::String, cdf::AbstractEmpiricalCDF, n=2000)

print `cdf` to file `fn`. Print no more than `n` linearly spaced points.
"""
function linprint(fn::String, cdf::AbstractEmpiricalCDF, n=2000; lastpt=false)
    io = open(fn,"w")
    linprint(io,cdf,n; lastpt=lastpt)
    close(io)
end

function logprint(fn::String, cdf::AbstractEmpiricalCDF, n=2000)
    io = open(fn,"w")
    logprint(io,cdf,n)
    close(io)
end

# print many fields, prpts is iterable
function _printfull(io, cdf::AbstractEmpiricalCDF, prpts; lastpt=false)
    n = length(cdf)
    println(io, "# log10(t)  log10(P(t))  log10(1-P(t))  t  1-P(t)   P(t)")
    state = start(prpts)
    (p,state) = next(prpts,state)
    ulim = lastpt ? n : n - 1 # usually don't print ordinate value of 1
#    println("ulim is ", ulim)
    for i in 1:ulim
        @inbounds xp = cdf.xdata[i]
        if done(prpts,state)
            break
        end
        if xp >= p
            (p,state) = next(prpts,state)
            cdf_val = _val_at_index(cdf,i)
            @printf(io,"%e\t%e\t%e\t%e\t%e\t%e\n", log10(abs(xp)),  log10(abs(1-cdf_val)), log10(abs(cdf_val)), xp, cdf_val, 1-cdf_val)
        end
    end
end

function _printextraheader(io,cdf::AbstractEmpiricalCDF)
end
function _printextraheader(io,cdf::EmpiricalCDFHi)
    nreject = _rejectcounts(cdf)
    n = length(cdf)
    println(io, "# cdf: lowreject = ", cdf.lowreject)
    println(io, "# cdf: lowreject counts = ", nreject)
    @printf(io, "# cdf: fraction kept = %f\n", n/(n+nreject))
end

# Note that we sort in place
function _printcdf(io::IO, cdf::AbstractEmpiricalCDF, logprint::Bool, nprint_pts::Integer; lastpt=false)
    if length(cdf) == 0
        error("Trying to print empty cdf")
    end
    x = cdf.xdata
    sort!(x)
    xmin = x[1]
    xmax = x[end]
    local prpts
    if logprint && xmin > 0
        println(io, "# cdf: log spacing of coordinate")
        prpts = logspace(log10(xmin),log10(xmax), nprint_pts)
    else
        println(io, "# cdf: linear spacing of coordinate")
        prpts = linspace(xmin,xmax, nprint_pts)
    end
    _printcdf(io, cdf, prpts; lastpt=lastpt)
end

# FIXME: We need to avoid resorting
function _printcdf(io::IO, cdf::AbstractEmpiricalCDF, prpts::AbstractArray; lastpt=false)
    x = cdf.xdata
    sort!(x)
    n = length(x)
    if n == 0
        error("Trying to print empty cdf")
    end
    println(io, "# cdf of survival times")
    println(io, "# cdf: total     counts = ", _total_counts(cdf))
    _printextraheader(io,cdf)
    println(io, "# cdf: number of points in cdf: $n")
    _printfull(io,cdf,prpts; lastpt=lastpt)
end
