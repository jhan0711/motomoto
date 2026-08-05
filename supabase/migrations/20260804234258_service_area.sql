-- =============================================================================
-- Fase 11A: area de servicio
-- =============================================================================
--
-- Cierra el hallazgo H11. El buscador de direcciones esta restringido a Amalfi
-- desde la Fase 9, pero el punto en el mapa no: hoy la chincheta se puede
-- arrastrar hasta otro municipio y confirmarla, y el conductor recibiria un
-- destino a treinta kilometros sin que nada protestara.
--
-- La validacion vive en el servidor y no en el cliente (D83). El cliente
-- propone un punto; aqui se decide si es atendible.
--
-- DECISION D150: el limite es el poligono real del municipio, no un circulo.
-- El recuadro de Amalfi llega a 43 km al norte del parque pero solo a 12 al
-- oeste. Un circulo que cubriera el municipio entero necesitaria 43 km de
-- radio, y con ese radio se tragaria Anori, Campamento, Yolombo y Segovia
-- enteros. El circulo no se descarto por gusto, sino por esos numeros.
--
-- Origen del dato: OpenStreetMap, relacion 1316177, admin_level 6.
-- Simplificado con st_simplifypreservetopology. La tolerancia se eligio
-- midiendo contra el original en PostGIS, no a ojo:
--
--   sin simplificar    2485 puntos   desviacion   0 m   area 1206,0 km2
--   tolerancia 0,0005   490 puntos   desviacion  56 m   area 1206,0 km2
--   tolerancia 0,001    270 puntos   desviacion 111 m   area 1205,8 km2
--   tolerancia 0,002    138 puntos   desviacion 221 m   area 1206,8 km2
--
-- Se eligio 0,0005: quita el 80% de los puntos, no mueve el area ni una decima
-- y su desviacion maxima es el 5% del margen de un kilometro que se aplica
-- encima. Los 1206 km2 coinciden con la superficie real del municipio, y eso es
-- lo que confirma que el poligono es el de Amalfi y no el de otro sitio.
--
-- Comprobado antes de escribir esta migracion: los 36 lugares de la Fase 9
-- caen dentro del poligono ya simplificado.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: service_area
-- -----------------------------------------------------------------------------

-- Una sola fila, garantizada por el tipo de la clave primaria mas la
-- restriccion: id es booleano, tiene que valer true, y true solo cabe una vez.
-- Cada empresa opera su propia instalacion (D9), asi que aqui nunca hay dos
-- municipios. El dia que eso cambie sera una migracion aditiva.
create table public.service_area (
  id boolean primary key default true,
  name text not null,
  boundary extensions.geography(Polygon, 4326) not null,
  source text not null,
  updated_at timestamptz not null default now(),
  constraint service_area_single_row check (id)
);

comment on table public.service_area is
  'Limite geografico dentro del cual se atienden solicitudes. Una sola fila.';

comment on column public.service_area.source is
  'De donde salio el poligono. Sin esto, dentro de un ano nadie sabria si se puede regenerar.';

create trigger service_area_set_updated_at
  before update on public.service_area
  for each row execute function public.set_updated_at();

-- Sin indice GIST a proposito. Un indice sirve para descartar filas deprisa y
-- aqui solo hay una: el planificador la lee entera de todos modos.

alter table public.service_area enable row level security;

-- Nadie la lee directamente desde la aplicacion. El pasajero pregunta si un
-- punto es valido a traves de la funcion de mas abajo, que es security definer
-- y no necesita politica. El administrador si tendra que verla en el panel
-- (Fase 20), y para eso esta esta politica.
create policy "service_area_select_admin"
  on public.service_area for select to authenticated
  using (public.is_admin());


-- -----------------------------------------------------------------------------
-- El poligono
-- -----------------------------------------------------------------------------

insert into public.service_area (name, boundary, source) values (
  'Amalfi',
  extensions.st_geomfromtext('POLYGON((-75.1828784 6.8498721,-75.1825177 6.8479061,-75.1812568 6.8470584,-75.1799492 6.8478801,-75.177773 6.8445896,-75.1775606 6.8435515,-75.1789718 6.841543,-75.1786213 6.8395994,-75.1775663 6.8393307,-75.1756424 6.836301,-75.1748088 6.8299018,-75.1730289 6.8253135,-75.1691142 6.8232944,-75.16752 6.819729,-75.1637375 6.8188302,-75.1615434 6.8157061,-75.158499 6.8137482,-75.1575639 6.8122558,-75.1552274 6.8114694,-75.1547554 6.810355,-75.1521598 6.8100503,-75.1514802 6.8076013,-75.1465694 6.8036082,-75.1438455 6.7996356,-75.1410202 6.7927441,-75.1347858 6.7917975,-75.1323586 6.786516,-75.1311217 6.7856812,-75.126112 6.7841095,-75.1216539 6.7841467,-75.1165975 6.7861867,-75.1114074 6.7831606,-75.1034972 6.7819458,-75.0973437 6.7843762,-75.0927908 6.7813773,-75.0936901 6.7790665,-75.0927141 6.777629,-75.0883223 6.7773938,-75.08672 6.7797037,-75.0850336 6.7793761,-75.083195 6.7748582,-75.0788083 6.7745158,-75.0782134 6.7725031,-75.0772899 6.77201,-75.0725597 6.7709788,-75.0714766 6.7718094,-75.0707517 6.770284,-75.0701591 6.771164,-75.0692816 6.7710038,-75.0652559 6.7681487,-75.0618526 6.7711122,-75.0601656 6.7706559,-75.0550138 6.7644759,-75.0449427 6.7584046,-75.0406514 6.756974,-75.0340302 6.7522211,-75.0303314 6.7518379,-75.0291469 6.7507441,-75.0251447 6.7575701,-75.0274354 6.7603028,-75.027683 6.7636883,-75.0342721 6.7654018,-75.0348361 6.7717477,-75.0363939 6.7778404,-75.0402052 6.7828594,-75.0432094 6.7905984,-75.0503497 6.7969466,-75.0508943 6.7989773,-75.0502833 6.807198,-75.0493977 6.8095419,-75.0469212 6.8109944,-75.0411064 6.809987,-75.0407004 6.8156434,-75.0423026 6.8178915,-75.042004 6.8194817,-75.0378385 6.8234489,-75.0355645 6.8304806,-75.0318566 6.8306349,-75.0295756 6.8333065,-75.0265917 6.834726,-75.0203557 6.8256169,-75.0206102 6.8250727,-75.0193697 6.8251363,-75.0196681 6.8243186,-75.0170369 6.8226167,-75.0165193 6.8197324,-75.012496 6.8154286,-75.0111669 6.8149133,-75.0094289 6.8155392,-75.010196 6.8145218,-75.0084351 6.8142941,-75.0085947 6.8134844,-75.0063658 6.8135337,-75.0055665 6.8118186,-75.0048423 6.8133926,-75.0033993 6.8126735,-75.0030345 6.8113445,-74.9973375 6.8120236,-74.9964684 6.8070433,-74.9937634 6.8065366,-74.9939867 6.8056837,-74.9927173 6.805464,-74.9938694 6.8040824,-74.9936682 6.8030457,-74.9925068 6.8032561,-74.9926168 6.8026089,-74.99145 6.8020229,-74.990522 6.8027101,-74.9901304 6.8018205,-74.990984 6.8012539,-74.9898689 6.8014357,-74.9901827 6.8008018,-74.9889173 6.7994275,-74.9875876 6.7997924,-74.9871048 6.7990267,-74.9877057 6.7983555,-74.9865228 6.7980919,-74.9869868 6.7975832,-74.9847981 6.7969679,-74.9839894 6.7951515,-74.9833524 6.7953193,-74.9836515 6.7941101,-74.9821883 6.7944031,-74.9826255 6.7932858,-74.9808928 6.7932565,-74.9802893 6.7920433,-74.9797784 6.7930062,-74.9795249 6.7918249,-74.9783877 6.7913429,-74.9768608 6.7917124,-74.9769835 6.7923816,-74.9736536 6.7913695,-74.974308 6.790187,-74.9727523 6.7892308,-74.9718484 6.7903681,-74.9710947 6.7875236,-74.9677909 6.7870128,-74.9666315 6.7858829,-74.9671841 6.7847003,-74.9662935 6.7844846,-74.9665779 6.7834805,-74.96499 6.78388,-74.9625063 6.7806093,-74.9636382 6.7788301,-74.9617821 6.7787928,-74.9623346 6.7773439,-74.9617499 6.7770562,-74.9629569 6.776742,-74.9617714 6.7751545,-74.9626726 6.7748615,-74.9615783 6.7747657,-74.9621737 6.7743715,-74.9616735 6.7739353,-74.960799 6.7743129,-74.9609667 6.7737069,-74.9603089 6.7741644,-74.960276 6.7732188,-74.958196 6.7737602,-74.9582094 6.7726781,-74.9577481 6.7734073,-74.9566748 6.7721201,-74.9553207 6.7722553,-74.9536014 6.7698595,-74.9540184 6.7670042,-74.9510566 6.7671327,-74.9512769 6.7658421,-74.9493444 6.7661431,-74.9490627 6.7646389,-74.9481508 6.7642021,-74.9445244 6.7644791,-74.9432048 6.7629236,-74.9426469 6.7635522,-74.941566 6.762775,-74.941802 6.7618161,-74.9404287 6.7601647,-74.9409574 6.757815,-74.9398041 6.7565098,-74.9383879 6.7565684,-74.936341 6.7549973,-74.9353891 6.7513157,-74.9344664 6.7524025,-74.9328946 6.7503408,-74.9305879 6.7517845,-74.9279434 6.7515449,-74.9237645 6.7498561,-74.9226835 6.7478768,-74.9226867 6.7666652,-74.9204731 6.7664061,-74.9118155 6.7680996,-74.9109841 6.769481,-74.9113579 6.7715509,-74.9139518 6.7763181,-74.9124415 6.7777876,-74.9093207 6.7776517,-74.9082072 6.7793523,-74.9054072 6.7794068,-74.9036215 6.783162,-74.9039572 6.7884033,-74.9048575 6.7898868,-74.902607 6.7922674,-74.9025689 6.7951461,-74.903788 6.7941108,-74.9051607 6.7941487,-74.9076699 6.7953046,-74.9090814 6.7972542,-74.9110214 6.797495,-74.9119224 6.7991095,-74.9117548 6.80129,-74.9084436 6.8035967,-74.908549 6.8081831,-74.9068006 6.8133181,-74.9050284 6.8154456,-74.903755 6.8189511,-74.9010772 6.8197039,-74.8984136 6.822245,-74.8961114 6.8293353,-74.8909402 6.8336034,-74.8840526 6.8368282,-74.8790606 6.8432083,-74.8768175 6.8475344,-74.8764618 6.8539592,-74.875418 6.8556745,-74.8741186 6.8661712,-74.8819079 6.8739945,-74.8835818 6.8799153,-74.8828712 6.8826035,-74.871212 6.8893621,-74.8696125 6.892789,-74.869557 6.8960411,-74.8711374 6.9004182,-74.8790662 6.9052324,-74.8783816 6.911172,-74.8762088 6.9141158,-74.8766543 6.9189571,-74.8795318 6.9227547,-74.8789332 6.9292627,-74.8780515 6.9308956,-74.8780236 6.9375616,-74.8768992 6.9393589,-74.8673064 6.9401674,-74.8618835 6.943625,-74.8544862 6.9443343,-74.8535905 6.9544217,-74.849264 6.9627481,-74.8491208 6.965188,-74.8475251 6.969119,-74.8473975 6.9735098,-74.8425748 6.9808647,-74.8406158 6.9902291,-74.8394059 6.9915395,-74.8371828 6.9988023,-74.8376441 7.0020076,-74.8393285 7.001209,-74.8401654 7.0018585,-74.8395431 7.0071403,-74.8399937 7.0136679,-74.837687 7.015031,-74.8370218 7.0224316,-74.8390818 7.0205469,-74.8402941 7.0174482,-74.8425257 7.0175866,-74.8432338 7.019514,-74.8454332 7.0203126,-74.8438346 7.0223997,-74.8447573 7.0244654,-74.8473752 7.0254025,-74.8488236 7.0235603,-74.8522675 7.0271488,-74.8550624 7.0254664,-74.8542953 7.0282456,-74.8547888 7.0294169,-74.8522031 7.0344747,-74.8564773 7.0367386,-74.8542523 7.0414066,-74.8556471 7.0452398,-74.8585439 7.04705,-74.8568809 7.0498503,-74.8583078 7.0528743,-74.8562799 7.0535242,-74.8563013 7.0564842,-74.8543487 7.056761,-74.8551292 7.0593164,-74.8540563 7.0595826,-74.8542414 7.0614672,-74.8527903 7.0635541,-74.8529432 7.0650448,-74.848362 7.0634476,-74.8457629 7.0651086,-74.8473964 7.0672376,-74.8472891 7.0705169,-74.8503012 7.0703365,-74.8511381 7.0717206,-74.8488206 7.0787264,-74.8432443 7.0812067,-74.8430619 7.0818881,-74.8456154 7.0838311,-74.8454598 7.0857688,-74.8431907 7.0877013,-74.8420212 7.0870838,-74.8391177 7.0875083,-74.839162 7.0900649,-74.8363323 7.093491,-74.8371182 7.0955852,-74.8388052 7.0960728,-74.8385936 7.0994341,-74.8396287 7.1017762,-74.8393578 7.1030756,-74.8374266 7.1047045,-74.8393471 7.1062908,-74.8381025 7.1103152,-74.8403905 7.1122416,-74.8401785 7.1143395,-74.8408947 7.1152226,-74.8405809 7.1176717,-74.839626 7.118731,-74.8403907 7.123516,-74.8391003 7.1258692,-74.8407686 7.1284562,-74.8403609 7.1298986,-74.8415679 7.130926,-74.8431129 7.1346574,-74.8451863 7.1347207,-74.8454762 7.1360276,-74.8484129 7.1367679,-74.8531042 7.1401447,-74.8533429 7.1467028,-74.8509801 7.1494383,-74.8525706 7.1527911,-74.8516667 7.1547717,-74.8491768 7.1562614,-74.8495041 7.1586459,-74.8477714 7.1618288,-74.8481544 7.163648,-74.8475192 7.1653449,-74.8477692 7.1662795,-74.8489708 7.1664668,-74.8505287 7.1653778,-74.8516613 7.166673,-74.8537001 7.1663093,-74.8557815 7.1682211,-74.8549886 7.1701383,-74.8561337 7.1761486,-74.8555637 7.1783412,-74.8565937 7.1793993,-74.8581147 7.1793883,-74.8601814 7.183324,-74.8606575 7.1877283,-74.8640163 7.1939432,-74.8642623 7.1976968,-74.8661191 7.1979774,-74.8665482 7.1989141,-74.866693 7.2022351,-74.8656577 7.2061096,-74.8723847 7.2139861,-74.8740455 7.2180883,-74.8758609 7.2195209,-74.8759896 7.2241616,-74.8768908 7.2247576,-74.8802382 7.2240764,-74.8824999 7.2254111,-74.8840034 7.2289261,-74.8852618 7.2299724,-74.8898828 7.2294104,-74.8970872 7.2328961,-74.9020225 7.2311665,-74.9077141 7.2315923,-74.9096878 7.2326677,-74.9140555 7.2433623,-74.9140555 7.2460444,-74.9158451 7.2504869,-74.9150426 7.2548994,-74.9161309 7.2577,-74.9147529 7.2606998,-74.9150682 7.263796,-74.9166712 7.2666065,-74.9176153 7.2725664,-74.9191603 7.2740989,-74.9193631 7.2759923,-74.9179569 7.2797104,-74.9179576 7.2826313,-74.9141443 7.2857833,-74.9132328 7.2884551,-74.9180416 7.2863687,-74.931117 7.2926567,-74.9367458 7.2886824,-74.939259 7.280777,-74.9356177 7.2758612,-74.9349861 7.2696211,-74.9313337 7.2611217,-74.931527 7.256898,-74.9333387 7.2529433,-74.9358875 7.2494357,-74.9429485 7.2456278,-74.9451832 7.2433526,-74.9487688 7.2323992,-74.9533085 7.2266014,-74.9588393 7.2217025,-74.9597807 7.215248,-74.9628901 7.2089635,-74.965216 7.207558,-74.9666047 7.2052968,-74.97097 7.2038607,-74.974477 7.2001753,-74.9792942 7.1972551,-74.9843789 7.1913205,-74.9904683 7.1873345,-74.9907178 7.1841411,-74.9945292 7.1823555,-74.9975771 7.1732826,-75.0023515 7.1678324,-75.0056581 7.1617445,-75.0053497 7.1596118,-75.0065012 7.158633,-75.0071138 7.1528716,-75.0132054 7.1493372,-75.0147665 7.1468409,-75.0178246 7.1450111,-75.0206515 7.1408911,-75.0208497 7.1376005,-75.0229423 7.1358027,-75.0254738 7.129616,-75.0263111 7.1243317,-75.0283242 7.1213768,-75.0292578 7.1164335,-75.0310544 7.114139,-75.0309712 7.1125378,-75.0321934 7.1107253,-75.0347509 7.1092831,-75.0324393 7.1066271,-75.0340478 7.1035917,-75.0335178 7.097587,-75.0375783 7.0851163,-75.0391551 7.0835584,-75.0398674 7.0807994,-75.043835 7.0790286,-75.048564 7.0716712,-75.053801 7.0682652,-75.0586039 7.0630629,-75.0564479 7.0425925,-75.0563126 7.03583,-75.0585033 7.0301931,-75.0581381 7.0235767,-75.0571971 7.0217816,-75.0599712 7.0179202,-75.0620046 7.0097896,-75.0637419 7.0096026,-75.065101 7.0077967,-75.0638686 7.0045536,-75.0643937 7.0011841,-75.063822 6.9980959,-75.0718406 6.9919406,-75.072729 6.99015,-75.0716615 6.988983,-75.0719314 6.9864075,-75.0729887 6.9856983,-75.0751376 6.9814603,-75.0764904 6.9809099,-75.0782303 6.9771417,-75.079314 6.9765645,-75.0822723 6.9694684,-75.0851003 6.9658003,-75.0903716 6.9621754,-75.0960525 6.9608901,-75.1030519 6.9560209,-75.110438 6.953183,-75.1154841 6.9491393,-75.1189591 6.9477586,-75.1229245 6.9473452,-75.1278064 6.9440447,-75.1330149 6.9432485,-75.1409727 6.9402913,-75.1412423 6.939328,-75.1400604 6.9381476,-75.1409263 6.930763,-75.1430153 6.9280295,-75.144023 6.9228273,-75.1487771 6.919619,-75.1631366 6.9152959,-75.1696572 6.9104918,-75.1716526 6.8979725,-75.1742941 6.8966255,-75.1748498 6.8922978,-75.1770366 6.8893172,-75.1798152 6.878806,-75.1782058 6.8737259,-75.1776817 6.8636059,-75.1793978 6.8575949,-75.1816179 6.8564871,-75.1810738 6.8522688,-75.1828784 6.8498721))', 4326)::extensions.geography,
  'OpenStreetMap relacion 1316177, admin_level 6, simplificado a 0,0005 grados'
);


-- -----------------------------------------------------------------------------
-- El margen
-- -----------------------------------------------------------------------------

-- DECISION D150. Va en app_settings y no fijado en el codigo, igual que el resto
-- de parametros operativos: la empresa debe poder ajustarlo sin publicar una
-- version nueva.
--
-- Por que existe el margen. El limite de OpenStreetMap en zona rural puede estar
-- desviado, y el GPS en zona de montana tambien. Un kilometro no alcanza el
-- casco de ningun municipio vecino, pero evita rechazar a alguien que esta
-- legitimamente en el borde y no entenderia por que.
insert into public.app_settings (key, value, description) values
  ('service_area_margin_m', '1000',
   'D150. Margen fuera del limite del municipio que aun se considera atendible.');


-- -----------------------------------------------------------------------------
-- Funcion: esta este punto dentro del area de servicio
-- -----------------------------------------------------------------------------

-- st_dwithin sobre geography devuelve verdadero tanto si el punto cae dentro del
-- poligono, donde la distancia es cero, como si cae fuera pero a menos del
-- margen. Una sola llamada cubre los dos casos.
--
-- Recibe longitud y latitud sueltas y no una geometria, para que el cliente
-- pueda llamarla tal cual y avisar en la pantalla del mapa en lugar de dejar que
-- el pasajero se entere tres pantallas mas adelante.
--
-- Es security definer porque service_area no es legible por un pasajero. Aun
-- asi no filtra nada: responde si o no sobre un punto que el mismo acaba de
-- elegir.
create or replace function public.is_within_service_area(
  p_lng double precision,
  p_lat double precision
)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
    from public.service_area a
    where extensions.st_dwithin(
            a.boundary,
            extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
            (public.get_setting('service_area_margin_m', '1000'))::double precision
          )
  );
$$;

comment on function public.is_within_service_area is
  'Si un punto es atendible: dentro del municipio o hasta el margen configurado fuera.';

grant execute on function public.is_within_service_area(double precision, double precision)
  to authenticated;


-- -----------------------------------------------------------------------------
-- request_ride: se le anaden las dos comprobaciones del area
-- -----------------------------------------------------------------------------

-- Se reescribe entera porque create or replace lo exige. Lo unico que cambia
-- respecto a la migracion 20260729013123 son los dos bloques marcados FASE 11.
create or replace function public.request_ride(
  p_origin_lng double precision,
  p_origin_lat double precision,
  p_origin_label text,
  p_destination_lng double precision,
  p_destination_lat double precision,
  p_destination_label text,
  p_passenger_count smallint,
  p_origin_place_id uuid default null,
  p_destination_place_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_max smallint;
  v_expiry integer;
  v_origin extensions.geography;
  v_request_id uuid;
  v_candidates integer;
begin
  select * into v_profile from public.profiles where id = v_uid;

  if not found then
    raise exception 'No se encontro tu perfil' using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  if v_profile.status = 'blocked' then
    raise exception 'Tu cuenta esta bloqueada. Comunicate con la empresa'
      using errcode = 'P0001', hint = 'ACCOUNT_BLOCKED';
  end if;

  if v_profile.role <> 'passenger' then
    raise exception 'Solo los pasajeros pueden solicitar servicios'
      using errcode = 'P0001', hint = 'NOT_A_PASSENGER';
  end if;

  -- Aqui se hace efectiva la obligatoriedad del telefono que profiles permite
  -- dejar vacio: un perfil incompleto es aceptable, una solicitud sin telefono
  -- de contacto no.
  if v_profile.phone is null then
    raise exception 'Necesitas registrar un telefono antes de solicitar un servicio'
      using errcode = 'P0001', hint = 'PHONE_REQUIRED';
  end if;

  -- REGLA R11, leida de la configuracion y no fijada en el codigo.
  v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
  if p_passenger_count < 1 or p_passenger_count > v_max then
    raise exception 'La cantidad de pasajeros debe estar entre 1 y %', v_max
      using errcode = 'P0001', hint = 'PASSENGER_COUNT_OUT_OF_RANGE';
  end if;

  -- FASE 11, DECISION D150. Van antes que el estado del pasajero porque validan
  -- los argumentos que acaba de enviar, que es lo mas barato de comprobar y lo
  -- mas concreto de explicar. Cierra H11.
  if not public.is_within_service_area(p_origin_lng, p_origin_lat) then
    raise exception 'El punto de recogida esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'ORIGIN_OUT_OF_AREA';
  end if;

  if not public.is_within_service_area(p_destination_lng, p_destination_lat) then
    raise exception 'El destino esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'DESTINATION_OUT_OF_AREA';
  end if;

  -- REGLA R6. El indice unico ya lo impide, pero un mensaje claro vale mas que
  -- una violacion de unicidad en la pantalla del usuario.
  if exists (
    select 1 from public.ride_requests
    where passenger_id = v_uid
      and status in ('searching', 'assigned', 'in_progress')
  ) then
    raise exception 'Ya tienes un servicio en curso'
      using errcode = 'P0001', hint = 'ACTIVE_REQUEST_EXISTS';
  end if;

  v_origin := extensions.st_setsrid(extensions.st_makepoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography;

  -- REGLA R1 revisada: si no hay ningun conductor disponible con capacidad, se
  -- avisa de inmediato en lugar de crear una solicitud que va a caducar tras
  -- cinco minutos de espera inutil.
  select count(*) into v_candidates
  from public.find_available_drivers(v_origin, p_passenger_count);

  if v_candidates = 0 then
    raise exception 'No hay motorratones disponibles en este momento'
      using errcode = 'P0001', hint = 'NO_DRIVERS_AVAILABLE';
  end if;

  v_expiry := (public.get_setting('request_expiry_seconds', '300'))::integer;

  insert into public.ride_requests (
    passenger_id, passenger_count,
    origin, origin_label, origin_place_id,
    destination, destination_label, destination_place_id,
    contact_phone, expires_at
  ) values (
    v_uid, p_passenger_count,
    v_origin, p_origin_label, p_origin_place_id,
    extensions.st_setsrid(extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326)::extensions.geography,
    p_destination_label, p_destination_place_id,
    v_profile.phone, now() + make_interval(secs => v_expiry)
  ) returning id into v_request_id;

  perform public.offer_request_to_drivers(v_request_id);

  return v_request_id;
end;
$$;

comment on function public.request_ride is
  'Crea una solicitud y la ofrece a los conductores cercanos. Unica via de creacion.';
