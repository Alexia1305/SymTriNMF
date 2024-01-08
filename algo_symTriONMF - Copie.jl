using Random
using LinearAlgebra
using IterTools
using Combinatorics
using Clustering
using Plots
gr()  # Configurer le backend GR
using SparseArrays

function min_degre4(a, b, c)
    # minimum du polynome de degré 4 ax^4 + bx^2 + cx
    # car pas 0 
    min = 1
    sol = a+b+c
    if a == 0
        x = -c / (2 * b)
        value = a * (x ^ 4) + b * (x ^ 2) + c * x
        if x > 0 && value < min
            sol = x
            min = value
        end
        return sol, min
    end

    # méthode de cardan
    p = 2 * b / (4 * a)
    q = c / (4 * a)
    delta = -(4 * (p ^ 3) + 27 * (q ^ 2))

    if delta < 0
        x = cbrt((-q + sqrt(-delta / 27)) / 2) + cbrt((-q - sqrt(-delta / 27)) / 2)
        value = a * (x ^ 4) + b * (x ^ 2) + c * x
        if x > 0 && value < min
            sol = x
            min = value
        end
    elseif delta == 0
        if p == q && q == 0
            x = 0
            value = 0
        else
            x = 3 * q / p
            value = a * (x ^ 4) + b * (x ^ 2) + c * x
            if x > 0 && value < min
                sol = x
                min = value
            end
            x = -3 * q / (2 * p)
            value = a * (x ^ 4) + b * (x ^ 2) + c * x
            if x > 0 && value < min
                sol = x
                min = value
            end
        end
    else
        for k in 0:2
            x = 2 * sqrt(-p / 3) * cos(
                (1 / 3) * acos((3 * q / (2 * p)) * ((3 / -p) ^ (1 / 2))) + (2 * k * π / 3)
            )
            value = a * (x ^ 4) + b * (x ^ 2) + c * x
            if x > 0 && value < min
                sol = x
                min = value
            end
        end
    end
    return sol, min
end

function calcul_erreur(X, W, S)
   
    error=1-((2*dot(W'*X,S*W')-dot((W'*W)*S,S*(W'*W)))/(dot(X,X)))
    return error
end

function calcul_accuracy(W_true,W_find)
    dim = size(W_true)
    n=dim[1]
    r=dim[2]
    vecteur_original=1:r
    toutes_permutations = collect(permutations(vecteur_original))

    maxi=-Inf
    for perm in toutes_permutations
        accuracy=float(0)
        for k in 1:r
            accuracy += count(x -> x[1] != 0 && x[2] != 0 , zip(W_true[:, k], W_find[:, perm[k]]))
        end
        if accuracy>maxi
            maxi=accuracy
        end 
    end 
    maxi /= float(n)
    return float(maxi)

end 

function symTriONMF_coordinate_descent(X, r, maxiter,epsi,init_kmeans,W_true)
    if init_kmeans == false 
        # initialisation aléatoire
        n = size(X, 1)
        W = zeros(n, r)
        for i in 1:n
            k = rand(1:r)
            W[i, k] = rand()
        end

        matrice_aleatoire = rand(r, r)
        S = 0.5 * (matrice_aleatoire + transpose(matrice_aleatoire))
    else 
        # initialisation kmeans 
        R=kmeans(X',r,maxiter=Int(ceil(maxiter*0.05)))
        a = assignments(R)  
        n = size(X, 1)
        W = zeros(n, r)
        for i in 1:n
            W[i, a[i]] = 1
        end
        matrice_aleatoire = rand(r, r)
        S = 0.5 * (matrice_aleatoire + transpose(matrice_aleatoire))
        #optimisation de S
         # optimisation de S
         for k in 1:r
            for l in 1:r  # symétrique
                a = 0
                b = 0
                ind_i = findall(W[:, k] .> 0)
                if isempty(ind_i)
                    break
                end
                ind_j = findall(W[:, l] .> 0)
                if isempty(ind_j)
                    break
                end
                for i in ind_i
                    for j in ind_j
                        a += (W[i, k] * W[j, l]) ^ 2
                        b += 2 * X[i, j] * W[i, k] * W[j, l]
                    end
                end
                S[k, l] = max(b / (2 * a), 0)
            end
        end
        println(calcul_accuracy(W_true,W))
    end 
    erreur_prec = calcul_erreur(X, W, S)
    erreur = erreur_prec
    

    for itter in 1:maxiter
        # optimisation de W
        for i in 1:n
            k_min = nothing
            k_min_value = nothing
            sum_value = Inf
            for k in 1:r
                a = S[k, k] ^ 2
                b = -2 * X[i, i] * S[k, k]
                c = 0
                for j in 1:n
                    if j == i
                        continue
                    end
                    l = argmax(W[j, :])  # l'élément non nul
                    b += 2 * (S[k, l] * W[j, l]) ^ 2
                    c += -4 * X[i, j] * S[k, l] * W[j, l]
                end
                x, value_x = min_degre4(a, b, c)
                if value_x < sum_value && x>0
                    k_min = k
                    k_min_value = x
                    sum_value = value_x
                end
            end
            W[i, :] .= 0
            W[i, k_min] = k_min_value
        end

       
        
        

        # optimisation de S
        for k in 1:r
            for l in 1:r  # symétrique
                a = 0
                b = 0
                ind_i = findall(W[:, k] .> 0)
                if isempty(ind_i)
                    break
                end
                ind_j = findall(W[:, l] .> 0)
                if isempty(ind_j)
                    break
                end
                for i in ind_i
                    for j in ind_j
                        a += (W[i, k] * W[j, l]) ^ 2
                        b += 2 * X[i, j] * W[i, k] * W[j, l]
                    end
                end
                S[k, l] = max(b / (2 * a), 0)
            end
        end

        erreur_prec = erreur
        erreur = calcul_erreur(X, W, S)
        println(calcul_accuracy(W_true,W))
        if erreur<epsi
            break
        end
        if abs(erreur_prec-erreur)<epsi
            break
        end
    end

    for k in 1:r
        nw=norm(W[:, k],2)
        if nw==0
            continue
        end     
        W[:, k] .= W[:, k] ./ nw
        
        S[k, :] .= S[k, :] .* nw
        S[:, k] .= S[:, k] .* nw
        
       
    end
   
   
    return W, S, erreur
end

function symTriONMF_update_rules(X, r, maxiter,epsi,init_kmeans,W_true)

    #Orthogonal Nonnegative Matrix Tri-factorizations for Clustering
    if init_kmeans == false 
        # initialisation aléatoire
        n = size(X, 1)
        W = zeros(n, r)
        for i in 1:n
            k = rand(1:r)
            W[i, k] = rand()
        end

        matrice_aleatoire = rand(r, r)
        S = 0.5 * (matrice_aleatoire + transpose(matrice_aleatoire))
    else 
        # initialisation kmeans 
        R=kmeans(X',r,maxiter=Int(ceil(maxiter*0.05)))
        a = assignments(R)  
        n = size(X, 1)
        W = zeros(n, r)
        for i in 1:n
            W[i, a[i]] = 1
        end
        matrice_aleatoire = rand(r, r)
        S = 0.5 * (matrice_aleatoire + transpose(matrice_aleatoire))
        #optimisation de S
         # optimisation de S
         for k in 1:r
            for l in 1:r  # symétrique
                a = 0
                b = 0
                ind_i = findall(W[:, k] .> 0)
                if isempty(ind_i)
                    break
                end
                ind_j = findall(W[:, l] .> 0)
                if isempty(ind_j)
                    break
                end
                for i in ind_i
                    for j in ind_j
                        a += (W[i, k] * W[j, l]) ^ 2
                        b += 2 * X[i, j] * W[i, k] * W[j, l]
                    end
                end
                S[k, l] = max(b / (2 * a), 0)
            end
        end
    println(calcul_accuracy(W_true,W))
    end 
    erreur_prec = calcul_erreur(X, W, S)
    erreur = erreur_prec
    

    for itter in 1:maxiter
        # optimisation de W
        for i in 1:n
            for k in 1:r
                num=X'*W*S
                den=W*W'*X'*W*S
                if den[i,k]== 0
                    continue
                end
                W[i,k]*=sqrt(num[i,k]/den[i,k])

            end
        end

       
        

        # optimisation de S
        for k in 1:r
            for l in 1:r  # symétrique
                num=W'*X*W
                den=W'*W*S*W'*W
                if den[k,l]== 0
                    continue
                end
                S[k,l]*=sqrt(num[k,l]/den[k,l])
            end
        end

        erreur_prec = erreur
        erreur = calcul_erreur(X, W, S)
        println(calcul_accuracy(W_true,W))
        if erreur<epsi
            break
        end
        if abs(erreur_prec-erreur)<epsi
            break
        end
    end

    for k in 1:r
        nw=norm(W[:, k],2)
        if nw==0
            continue
        end     
        W[:, k] .= W[:, k] ./ nw
        
        S[k, :] .= S[k, :] .* nw
        S[:, k] .= S[:, k] .* nw
        
       
    end
   
    erreur2 = calcul_erreur(X, W, S)
      
    return W, S, erreur2
end

# création matrice
n = 100
r = 7
W_true2 = zeros(n, r)
for i in 1:n
    k = rand(1:r)
    W_true2[i, k] = rand()+1
end

# Supprimer les colonnes nulles
# Trouver les indices des colonnes non-nulles
indices_colonnes_non_nulles = findall(x -> any(x .!= 0), eachcol(W_true2))

# Extraire les colonnes non-nulles
W_true = W_true2[:, indices_colonnes_non_nulles]
r = size(W_true, 2)
#normaliser 
for j in 1:r
    W_true2[:, j] .= W_true2[:, j] ./ norm(W_true2[:, j],2)
end
# Densité de la matrice (proportion d'éléments non nuls)
density = 0.4

# Générer une matrice sparse aléatoire
random_sparse_matrix = sprand(r, r, density)
S=Matrix(random_sparse_matrix)
S = 0.5 * (S + transpose(S))
# Mettre les éléments diagonaux à 1
for k in 1:r
    S[k,k]=1
end 
X = W_true * S* transpose(W_true)
N = randn(n,n); 
N = 2* (N/norm(N))*norm(X);  
X=X+N
X=max.(X, 0) # pas de vaelurs négatives 
maxiter=1000
epsi=10e-5
# algorithme :
temps_execution_1 = @elapsed begin
    W, S, erreur = symTriONMF_coordinate_descent(X, r, maxiter,epsi,false,W_true)
end
temps_execution_2 = @elapsed begin
    W2, S2, erreur2 = symTriONMF_update_rules(X, r, maxiter,epsi,false,W_true)
end 