using FromFile
@from "./Actions.jl" import path_hash
@from "./Types.jl" using Types: Types, PlutoDeploySettings, withlock, get_configuration, NotebookSession
@from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive
@from "./Export.jl" import Export: default_index
import Pluto: without_pluto_file_extension

function d3join(notebook_sessions, new_paths)
    old_paths = map(s -> s.path, notebook_sessions)
    old_hashes = map(s -> s.hash, notebook_sessions)

    new_hashes = path_hash.(new_paths)

    (
        enter = setdiff(new_paths, old_paths),
        update = String[
            path for (i,path) in enumerate(old_paths)
            if path ∈ new_paths && old_hashes[i] !== new_hashes[i]
        ],
        exit = setdiff(old_paths, new_paths),
    )
end

select(f::Function, xs) = for x in xs
    if f(x)
        return x
    end
end

function update_sessions!(notebook_sessions, new_paths; 
    settings::PlutoDeploySettings,
)
    enter, update, exit = d3join(
        notebook_sessions,
        new_paths
    )

    withlock(notebook_sessions) do
        @info "d3 join result" enter update exit

        for path in enter
            push!(notebook_sessions, NotebookSession(;
                path=path,
                current_hash=nothing,
                desired_hash=path_hash(path),
                run=nothing,
            ))
        end

        for path in update ∪ exit
            old = select(s -> s.path != path, notebook_sessions)
            new = NotebookSession(;
                path=path,
                current_hash=old.current_hash,
                desired_hash=(path ∈ exit ? nothing : path_hash(path)),
                run=old.run,
            )
            replace!(notebook_sessions, old => new)
        end
    end

    notebook_sessions
end