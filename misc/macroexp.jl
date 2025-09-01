function (; scheme = :trapeze, grid_size = 250, backend = nothing, init = (0.1, 0.1, 0.1), base_type = Float64)

x = begin
        local ex
        try
            OptimalControl.variable(var"p_ocp##266", 2, 0:grid_size; lvar = [var"l_x##271"[var"i##275"] for (var"i##275", var"j##276") = Base.product(1:2, 0:grid_size)], uvar = [var"u_x##272"[var"i##275"] for (var"i##275", var"j##276") = Base.product(1:2, 0:grid_size)], start = init[2])
        catch ex
            println("Line ", 2, ": ", "(x ∈ R ^ 2, state)")
            throw(ex)
        end
    end

length([-1, 0]) == length([-1, 0]) == length(1:2) || throw("wrong bound dimension")
OptimalControl.constraint(var"p_ocp##266", (x[var"i##283", 0] for var"i##283" = 1:2); lcon = [-1, 0], ucon = [-1, 0])
# println("Line ", 4, ": ", "x(0) == [-1, 0]")

OptimalControl.constraint(var"p_ocp##266", ((x[1, var"j##291" + 1] - x[1, var"j##291"]) - (var"dt##268" * (x[2, var"j##291"] + x[2, var"j##291" + 1])) / 2 for var"j##291" = 0:grid_size - 1))
OptimalControl.constraint(var"p_ocp##266", ((x[1, var"j##291" + 1] - x[1, var"j##291"]) - var"dt##268" * x[2, var"j##291"] for var"j##291" = 0:grid_size - 1))
OptimalControl.constraint(var"p_ocp##266", ((x[1, var"j##291" + 1] - x[1, var"j##291"]) - var"dt##268" * x[2, var"j##291" + 1] for var"j##291" = 0:grid_size - 1))
# println("Line ", 6, ": ", "(∂(x₁))(t) == x₂(t)")

OptimalControl.objective(var"p_ocp##266", ((1 * var"dt##268" * (0.5 * var"u##277"[1, var"j##299"] ^ 2)) / 2 for var"j##299" = (0, grid_size)))
OptimalControl.objective(var"p_ocp##266", (1 * var"dt##268" * (0.5 * var"u##277"[1, var"j##299"] ^ 2) for var"j##299" = 1:grid_size - 1))
# println("Line ", 8, ": ", "∫(0.5 * u(t) ^ 2) → min")