
dir = @_DIR_

function read_matrix(filepath)

    lines = readlines(filepath)
    data = [split(line) for line in lines]

    labels = unique(vcat(
        [t[1] for t in data],
        [t[2] for t in data]
    ))

    index = Dict(label => i for (i, label) in enumerate(labels))

    n = length(labels)
    D = fill(NaN, n, n)

    for t in data
        i = index[t[1]]
        j = index[t[2]]
        D[i, j] = parse(Float64, t[3])
    end

    D  # distance matrix 
end 


function find_distance(letter_up, letter_left, number_up, number_left, number_upleft)
    if letter_up == letter_left 
      return min(number_up,number_left,number_upleft)
    else
      return 1 + min(number_up,number_left,number_upleft)
    end
end


function uninformed_edit_distance(word1, word2)
    word_up = word1 
    word_left = word2
    n = length(word_up)
    m = length(word_left)
    distances = zeros(Uint8,m+1,n+1)
    for i in 1:m+1 
        distances[i,1]
    end
    for i in 1:n+1 
        distances[1,i]
    end

    for i in 2:m+1 
        for j in 2:n+1 
            distances[i,j] = find_distance(word_up[j-1], word_left[i-1], distances[i-1,j], distances[i,j-1],distances[i-1,j-1])
        end
    end
    return distances[m+1,n+1]
end
