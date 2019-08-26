fs   = require("fs").promises
path = require "path"

removeRecursively = (directory) ->
    if await fs.access directory
        for file in await fs.readdir directory
            entry = path.join directory, file
            stat  = await fs.stat entry

            removeRecursively entry if stat.isDirectory()
            await fs.unlink entry

        await fs.rmdir directory

module.exports = removeRecursively
