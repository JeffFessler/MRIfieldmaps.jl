#=
combine.jl
Complex coil combination
=#

export coil_combine


"""
    zdata, sos = coil_combine(ydata, smap; kwargs...)

For estimating a B0 field map
from complete multi-coil image data,
it suffices to first do complex coil combination,
while tracking the sum-of-squares `sos`
for proper weighting.
Often `sos` is all 1's and 0's.

# In
- `ydata (dims..., nc, ne)` `ne ≥ 1` sets of complex images for `nc ≥ 1` coils
- `smap (dims..., nc)` complex coil maps

# Out
- `zdata (dims..., ne)` complex coil combination: `sum_c smap[c]' * ydata[c] ./ sos`
- `sos (dims...)` sum-of-squares: `sum_c |smap[c]|^2`
"""
function coil_combine(
    ydata::AbstractArray{<:Complex},
    smap::AbstractArray{<:Complex},
)

    Base.require_one_based_indexing(smap, ydata)

    dims = size(ydata)[1:end-2]
    ndim = length(dims)
    nc = size(ydata)[ndim+1]
    ne = size(ydata)[ndim+2]

    # check dimensions
    size(smap) == (dims..., nc) ||
        throw("bad smap size $(size(smap)) != $((dims..., nc))")

    # coil combine image data
    sos = sum(abs2, smap, dims=ndim+1)
    sos = selectdim(sos, ndim+1, 1)
    smap = div0.(smap, sos)
    zdata = sum(conj(smap) .* ydata; dims=ndim+1) # coil combine
    zdata = selectdim(zdata, ndim+1, 1) # (dims..., ne)

    return zdata, sos
end


function coil_combine(
    ydata::AbstractArray{<:Complex},
    smap::Nothing = nothing,
)

    Base.require_one_based_indexing(ydata)

    dims = size(ydata)[1:end-2]
    ndim = length(dims)
    nc = size(ydata)[ndim+1]
    ne = size(ydata)[ndim+2]

    y = ntuple(ne) do e
        ye = selectdim(ydata, ndim+2, e)
        [selectdim(ye, ndim+1, c) for c = 1:nc]
    end
    y1 = y[1]

    sos = sum(yc1 -> abs2.(yc1), y1)
    sos = sqrt.(sos)
    y1sos = map(yc1 -> yc1 ./ sos, y1)
    zdata = map(y) do ye
        mapreduce(+, y1sos, ye) do yc1sos, yce
            conj.(yc1sos) .* yce
        end
    end
    zdata = cat(zdata..., dims=ndim+1)
    sos ./= maximum(sos) # Seems to help keep regularization parameter scale-independent

    return zdata, sos
end
