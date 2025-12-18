dir = @__DIR__
filepath = joinpath(dir, "keyboard_layout_distance.txt")

filepath2 = joinpath(dir, "words_alpha.txt")

function create_dictionary(filepath)
    lines = readlines(filepath)
    data = [split(line) for line in lines]

    D = Dict{Tuple{String, String}, Float64}()

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
        return 1 + min(number_up,number_left,number_upleft)
    end
end


function uninformed_edit_distance(word1, word2)
    word_up = word1 
    word_left = word2
    n = length(word_up)
    m = length(word_left)
    distances = zeros(Int,m+1,n+1)
    for i in 1:m+1 
        distances[i,1] = i-1
    end
    for i in 1:n+1 
        distances[1,i] = i-1
    end

    for i in 2:m+1 
        for j in 2:n+1 
            distances[i,j] = find_distance(word_up[j-1], word_left[i-1], distances[i-1,j], distances[i,j-1],distances[i-1,j-1])
        end
    end
    return distances[m+1,n+1]
end

s = "misspelling"
t = "ispellnig"

uninformed_edit_distance(s,t)

D = create_dictionary(filepath)
D = normalize_dictionary!(D)
