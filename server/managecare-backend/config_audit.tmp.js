const dotenv = require('dotenv');
dotenv.config({ path: '/opt/managecare-backend/.env' });
dotenv.config({ path: '/opt/managecare-backend/.env.production' });
const { Pool } = require('pg');
const pool = new Pool();
(async()=>{
  try {
    const r=await pool.query('SELECT current_database() AS db, current_user AS role, inet_server_addr()::text AS server_addr, inet_server_port() AS port');
    console.log(JSON.stringify({...r.rows[0], configured_supabase_url:Boolean(process.env.SUPABASE_URL), configured_service_role:Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY)}));
  } catch(e){console.error('CONNECTION_CHECK_FAILED',e.code||'');process.exitCode=1}
  finally{await pool.end()}
})();
