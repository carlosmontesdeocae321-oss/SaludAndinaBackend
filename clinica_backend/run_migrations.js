const fs = require('fs');
const path = require('path');
const pool = require('./config/db');

async function runMigrations() {
  const migrationsDir = path.join(__dirname, 'migrations');
  if (!fs.existsSync(migrationsDir)) {
    console.error('No se encontró la carpeta migrations/');
    process.exit(1);
  }

  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log('No hay archivos .sql en migrations/');
    process.exit(0);
  }

  for (const file of files) {
    const fullPath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(fullPath, 'utf8').trim();
    if (!sql) {
      console.log(`${file} está vacío, saltando`);
      continue;
    }

    console.log(`Ejecutando migración: ${file}`);
    try {
      // Antes de ejecutar: detectar si el SQL intenta añadir una columna que ya existe
      const alterTableMatch = sql.match(/ALTER\s+TABLE\s+`?([a-zA-Z0-9_]+)`?/i);
      const addColumnMatch = sql.match(/ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([a-zA-Z0-9_]+)`?/i);
      if (alterTableMatch && addColumnMatch) {
        const tableName = alterTableMatch[1];
        const columnName = addColumnMatch[1];
        const [existRows] = await pool.query(
          'SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
          [tableName, columnName]
        );
        const exists = existRows[0].c > 0;
        if (exists) {
          console.log(`Saltando ${file}: la columna '${columnName}' ya existe en la tabla '${tableName}'.`);
          continue;
        }
      }

      // Ejecuta el contenido del archivo SQL
      await pool.query(sql);
      console.log(`OK: ${file}`);
    } catch (err) {
      // Si es un error de columna duplicada, lo mostramos y seguimos con las demás migraciones
      const msg = err && (err.message || err.toString());
      if (msg && /Duplicate column name/i.test(msg)) {
        console.warn(`Advertencia: columna duplicada detectada en ${file}: ${msg}. Saltando archivo.`);
        continue;
      }

      console.error(`Error ejecutando ${file}:`, msg);
      console.error('Deteniendo migraciones. Revisa el error y corrige el SQL antes de reintentar.');
      await pool.end();
      process.exit(1);
    }
  }

  console.log('Todas las migraciones aplicadas.');
  await pool.end();
  process.exit(0);
}

runMigrations();
