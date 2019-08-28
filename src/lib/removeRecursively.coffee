fs   = require("fs").promises
path = require "path"
log  = (require "../lib/Logger") "removeRecursively"

removeRecursively = (directory) ->
    try
        if await fs.access directory
            for file in await fs.readdir directory
                entry = path.join directory, file
                stat  = await fs.stat entry

                removeRecursively entry if stat.isDirectory()
                await fs.unlink entry

            await fs.rmdir directory
    catch error
        return log.error "Insufficient permission to remove #{directory}" if error.code is "EACCES"
        return log.warn "Failed to remove #{directory} (is it mounted?)"  if error.code is "ENOENT"
        throw error

module.exports = removeRecursively
