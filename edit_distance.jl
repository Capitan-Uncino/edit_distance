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
    D[key] = parse(Float64, t[3])
  end

  return D
end

function normalize_dictionary!(D)
  max_val, max_key = findmax(D)

  for k in keys(D)
    D[k] = D[k] / max_val
  end
  return D
end


function find_uninformed_distance(letter_up, letter_left, number_up, number_left, number_upleft)
  if letter_up == letter_left
    return number_upleft
  else
    return 1 + min(number_up, number_left, number_upleft)
  end
end


function find_informed_distance(letter_up, letter_left, number_up, number_left, number_upleft, D, probs)
  if letter_up == letter_left
    return number_upleft
  else
    key = (string(letter_up), string(letter_left))
    cost_substitute = get(D, key, 1.0)

    cost_delete = 1.0

    cost_insert = 1.0
    if haskey(probs, letter_up)
      cost_insert = 1.0 - maximum(values(probs[letter_up]))
    end

    cost = min(number_up + cost_delete, number_left + cost_insert, number_upleft + cost_substitute)
    return cost
  end
end



function uninformed_edit_distance(word1, word2)
  word_up = word1         # correct word
  word_left = word2       # misspelled word
  m = length(word_left)
  n = length(word_up)
  distances = zeros(Int, m + 1, n + 1)
  for i in 1:m+1
    distances[i, 1] = i - 1
  end
  for j in 1:n+1
    distances[1, j] = j - 1
  end

  for i in 2:m+1
    for j in 2:n+1
      distances[i, j] = find_uninformed_distance(word_up[j-1], word_left[i-1],
        distances[i-1, j], distances[i, j-1], distances[i-1, j-1])
    end
  end
  return distances[m+1, n+1]
end


function informed_edit_distance(word1, word2, D, probs)
  word_up = word1         # correct word
  word_left = word2       # misspelled word
  n = length(word_up)
  m = length(word_left)
  distances = zeros(Float64, m + 1, n + 1)
  for i in 1:m+1
    distances[i, 1] = i - 1
  end
  for i in 1:n+1
    distances[1, i] = i - 1
  end

  for i in 2:m+1
    for j in 2:n+1
      distances[i, j] = find_informed_distance(word_up[j-1], word_left[i-1],
        distances[i-1, j], distances[i, j-1], distances[i-1, j-1], D, probs)
    end
  end
  return distances[m+1, n+1]
end


function initialize_swaps_distribution_1(distances_path)
  lines = readlines(distances_path)

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


function sample_swap(probs, from::Char)
  letters = collect(keys(probs[from]))
  p = [probs[from][l] for l in letters]
  return letters[rand(Categorical(p))]
end



using Distributions

function apply_errors(
  strings::Vector{String},
  sub_probs::Dict{Char,Dict{Char,Float64}},
  ins_probs::Dict{Char,Float64},
  del_probs::Dict{Char,Float64},
  alphabet::Vector{Char}
)

  out = Vector{String}(undef, length(strings))

  for (i, s) in enumerate(strings)
    chars = collect(s)
    j = 1

    while j ≤ length(chars)
      c = chars[j]

      ps = haskey(sub_probs, c) ? sum(values(sub_probs[c])) : 0.0
      pi = get(ins_probs, c, 0.0)
      pd = get(del_probs, c, 0.0)

      p_no = max(0.0, 1.0 - (ps + pi + pd))

      error_type = rand(Categorical([ps, pi, pd, p_no]))

      if error_type == 1   # substitution
        if haskey(sub_probs, c)
          letters = collect(keys(sub_probs[c]))
          p = [sub_probs[c][l] for l in letters]
          chars[j] = letters[rand(Categorical(p))]
        end
        j += 1

      elseif error_type == 2   # insertion (uniform char)
        insert!(chars, j, rand(alphabet))
        j += 2

      elseif error_type == 3   # deletion
        deleteat!(chars, j)
        # do NOT increment j

      else   # no error
        j += 1
      end
    end

    out[i] = String(chars)
  end

  return out
end


function find_closest_word_uninformed(words_correct, words_err)
  closest_words = Dict{String,String}()
  closest = ""

  for s_err in words_err
    d_min = Inf
    for s_corr in words_correct
      d = uninformed_edit_distance(s_corr, s_err)
      if d < d_min
        d_min = d
        closest = s_corr
      end
    end

    closest_words[s_err] = closest
  end

  return closest_words
end


function find_closest_word_informed(words_correct, words_err, D, probs)
  closest_words = Dict{String,String}()
  closest = ""

  for s_err in words_err
    d_min = Inf
    for s_corr in words_correct
      d = informed_edit_distance(s_corr, s_err, D, probs)
      if d < d_min
        d_min = d
        closest = s_corr
      end
    end

    closest_words[s_err] = closest
  end

  return closest_words
end



s = "misspelling"
t = "ispellnig"

uninformed_edit_distance(s, t)

D = create_dictionary(filepath)
D = normalize_dictionary!(D)

words = readlines(filepath2)
words = words[1:1000]


probs = initialize_swaps_distribution_1(filepath)
words = uppercase.(words)

alphabet = collect('a':'z')

words_sbagliate = apply_errors(words, probs, Dict(c => 1 / length(alphabet) for c in alphabet), Dict(c => 1 / length(alphabet) for c in alphabet), alphabet)


# Uninformed
closest_uninformed = find_closest_word_uninformed(words, words_sbagliate)

num_correct = 0
num_incorrect = 0

for (original, error) in zip(words, words_sbagliate)
  global num_correct, num_incorrect
  correct = closest_uninformed[error]

  if original == correct
    num_correct += 1
  else
    num_incorrect += 1
  end
end

println("UNINFORMED: \nCorrect words: ", num_correct)
println("Incorrect words: ", num_incorrect)
println("Accuracy uninformed: ", round(num_correct / length(words) * 100, digits=2), "%")


# Informed test
closest_informed = find_closest_word_informed(words, words_sbagliate, D, probs)

num_correct = 0
num_incorrect = 0

for (original, error) in zip(words, words_sbagliate)
  global num_correct, num_incorrect
  correct = closest_informed[error]

  if original == correct
    num_correct += 1
  else
    num_incorrect += 1
  end
end

println("\nINFORMED: \nCorrect words: ", num_correct)
println("Incorrect words: ", num_incorrect)
println("Accuracy informed version: ", round(num_correct / length(words) * 100, digits=2), "%")
