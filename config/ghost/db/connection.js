const fs = require("fs");
const knex = require('knex');
const config = require('../../../shared/config');
const logging = require('../../../shared/logging');
const errors = require('@tryghost/errors');
let knexInstance;


/**
 * Read a Docker Secret from a specified path. Terminates node execution when the secret cannot be found.
 *
 * @param {*} secretNameAndPath Path and name of the Docker Secret.
 * @returns A Docker Secret string.
 */
function readSecret(secretNameAndPath) {
    try {
        const val = fs.readFileSync(`${secretNameAndPath}`, "utf8")
        return val
    } catch(err) {
        console.log(`ERROR: Docker secret '${secretNameAndPath}' not found`)
        process.exit(1)
    }
}

// @TODO:
// - if you require this file before config file was loaded,
// - then this file is cached and you have no chance to connect to the db anymore
// - bring dynamic into this file (db.connect())
function configure(dbConfig) {
    var client = dbConfig.client;

    if (client === 'sqlite3') {
        dbConfig.useNullAsDefault = Object.prototype.hasOwnProperty.call(dbConfig, 'useNullAsDefault') ? dbConfig.useNullAsDefault : true;
    }

    if (client === 'mysql') {
        dbConfig.connection.timezone = 'UTC';
        dbConfig.connection.charset = 'utf8mb4';

        dbConfig.connection.loggingHook = function loggingHook(err) {
            common.logging.error(new common.errors.InternalServerError({
                code: 'MYSQL_LOGGING_HOOK',
                err: err
            }));
        };
    }

    // read database user from secret if file is specified
    let userFile = process.env.database__connection__user__file
    if (userFile) {
        let db_user= readSecret(userFile)
        dbConfig.connection.user = db_user
    }

    // read database password from secret if file is specified
    let passwordFile = process.env.database__connection__password__file
    if (passwordFile) {
        let db_password = readSecret(passwordFile)
        dbConfig.connection.password = db_password
    }

    return dbConfig;
}

if (!knexInstance && config.get('database') && config.get('database').client) {
    knexInstance = knex(configure(config.get('database')));
}

module.exports = knexInstance;