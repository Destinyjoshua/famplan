const fs = require('fs');

const supabaseUrl = process.env.SUPABASE_URL?.trim();
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY?.trim();

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn(
    'SUPABASE_URL and SUPABASE_ANON_KEY are not set. config.js will be empty and the setup screen will appear.',
  );
  fs.writeFileSync('config.js', 'window.FAMPLANS_ADMIN_CONFIG = null;\n');
  process.exit(0);
}

const config = { supabaseUrl, supabaseAnonKey };
fs.writeFileSync(
  'config.js',
  `window.FAMPLANS_ADMIN_CONFIG = ${JSON.stringify(config, null, 2)};\n`,
);

console.log('Generated config.js for', supabaseUrl);