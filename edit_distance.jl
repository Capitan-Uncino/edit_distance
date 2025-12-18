using Distributions
dir = @__DIR__
filepath = joinpath(dir, "keyboard_layout_distance.txt")

filepath2 = joinpath(dir, "words_alpha.txt")

function create_dictionary(filepath)
  lines = readlines(filepath)
  data = [split(line) for line in lines]

  D = Dict{Tuple{String,String},Float64}()

  for t in data
    key = (t[1], t[2])
    value = parse(Float64, t[3])
    D[key] = value
  end

  return D
end

function normalize_dictionary!(D)
  max_val, max_key = findmax(D)
  println(max_val)
  for k in keys(D)
    D[k] = D[k] / max_val
  end
  return D
end


function find_distance(letter_up, letter_left, number_up, number_left, number_upleft)
  if letter_up == letter_left
    return number_upleft
    #return min(number_up,number_left,number_upleft)
  else
    return 1 + min(number_up, number_left, number_upleft)
  end
end


function uninformed_edit_distance(word1, word2)
  word_up = word1
  word_left = word2
  n = length(word_up)
  m = length(word_left)
  distances = zeros(Int, m + 1, n + 1)
  for i in 1:m+1
    distances[i, 1] = i - 1
  end
  for i in 1:n+1
    distances[1, i] = i - 1
  end

  for i in 2:m+1
    for j in 2:n+1
      distances[i, j] = find_distance(word_up[j-1], word_left[i-1], distances[i-1, j], distances[i, j-1], distances[i-1, j-1])
    end
  end
  return distances[m+1, n+1]
end


function initialize_swaps_distribution_1(distances_path)


  lines = readlines(distances_path)

  # store as: dict[from_letter] = Dict(to_letter => distance)
  dist = Dict{Char,Dict{Char,Float64}}()

  for line in lines
    a, b, d = split(line)
    d = parse(Float64, d)

    from = a[1]
    to = b[1]

    get!(dist, from, Dict{Char,Float64}())[to] = d
  end


  weights = Dict{Char,Dict{Char,Float64}}()

  for (from, targets) in dist
    w = Dict{Char,Float64}()
    for (to, d) in targets
      w[to] = 1 / (d + 1)
    end
    weights[from] = w
  end

  probs = Dict{Char,Dict{Char,Float64}}()

  for (from, w) in weights
    Z = sum(values(w))
    probs[from] = Dict(to => wt / Z for (to, wt) in w)
  end

  return probs
end



function initialize_swaps_distribution_2(distances_path)


  lines = readlines(distances_path)

  # store as: dict[from_letter] = Dict(to_letter => distance)
  dist = Dict{Char,Dict{Char,Float64}}()

  for line in lines
    a, b, d = split(line)
    d = parse(Float64, d)

    from = a[1]
    to = b[1]

    get!(dist, from, Dict{Char,Float64}())[to] = d
  end


  weights = Dict{Char,Dict{Char,Float64}}()


  τ = 30.0

  for (from, targets) in dist
    w = Dict{Char,Float64}()
    for (to, d) in targets
      w[to] = exp(-d / τ)
    end
    weights[from] = w
  end


  probs = Dict{Char,Dict{Char,Float64}}()

  for (from, w) in weights
    Z = sum(values(w))
    probs[from] = Dict(to => wt / Z for (to, wt) in w)
  end

  return probs
end



using Distributions

function sample_swap(probs, from::Char)
  letters = collect(keys(probs[from]))
  p = [probs[from][l] for l in letters]
  return letters[rand(Categorical(p))]
end


function apply_swaps(strings::Vector{String},
  probs::Dict{Char,Dict{Char,Float64}})
  out = Vector{String}(undef, length(strings))

  for (i, s) in enumerate(strings)
    chars = collect(s)

    for j in eachindex(chars)
      c = chars[j]

      # only swap letters we have probabilities for
      if haskey(probs, c)
        letters = collect(keys(probs[c]))
        p = [probs[c][l] for l in letters]
        chars[j] = letters[rand(Categorical(p))]
      end
    end

    out[i] = String(chars)
  end

  return out
end


s = "misspelling"
t = "ispellnig"

uninformed_edit_distance(s, t)

D = create_dictionary(filepath)
D = normalize_dictionary!(D)

#words = readlines(filepath2)


probs = initialize_swaps_distribution_1(filepath)
words = ["pizza", "pasta", "mandolino"]
words_sbagliate = apply_swaps(words, probs)

println(words)
println(words_sbagliate)
