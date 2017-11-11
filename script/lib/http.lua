module(...,package.seeall)

require "common"
require"socket"
local lpack=require"pack"

local sfind,slen,ssub,smatch,sgmatch= string.find,string.len,string.sub,string.match,string.gmatch
--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("http",...)
end

--http clients�洢��
local tclients = {}

--[[
��������getclient
����  ������һ��http client��tclients�е�����
����  ��
	  sckidx��http client��Ӧ��socket����
����ֵ��sckidx��Ӧ��http client��tclients�е�����
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
��������datinactive
����  ������ͨ���쳣����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
		sckidx��socket idx
        data�����͵����ݣ��ڷ��ͽ���¼���������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼���������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(sckidx,data,para)
    return socket.send(sckidx,data,para)
end

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--[[
��������reconn
����  ��socket������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ�������������
����  ��
		sckidx��socket idx
����ֵ����
]]
function reconn(sckidx)
	local httpclientidx = getclient(sckidx)
	print("reconn",tclients[httpclientidx].sckreconncnt,tclients[httpclientidx].sckconning,tclients[httpclientidx].sckreconncyclecnt)
	--sckconning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������sckreconncnt���ӣ�ʵ�ʵ�������������
	if tclients[httpclientidx].sckconning then return end
	--һ�����������ڵ�����
	if tclients[httpclientidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[httpclientidx].sckreconncnt = tclients[httpclientidx].sckreconncnt+1
		socket.disconnect(sckidx)
		tclients[httpclientidx].sckconning = true
	--һ���������ڵ�������ʧ��
	else
		tclients[httpclientidx].sckreconncnt,tclients[httpclientidx].sckreconncyclecnt = 0,tclients[httpclientidx].sckreconncyclecnt+1
		if tclients[httpclientidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			if tclients[httpclientidx].sckerrcb then
				tclients[httpclientidx].sckreconncnt=0
				tclients[httpclientidx].sckreconncyclecnt=0
				tclients[httpclientidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			link.shut()
		end		
	end
end

local function connectitem(httpclientidx)
	connect(tclients[httpclientidx].sckidx,tclients[httpclientidx].prot,tclients[httpclientidx].host,tclients[httpclientidx].port)
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�������
����  ��
        idx��number���ͣ�socket��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	local httpclientidx = getclient(idx)
	print("ntfy",evt,result,item)
	--���ӽ��������socket.connect����첽�¼���
	if evt == "CONNECT" then
		tclients[httpclientidx].sckconning = false
		--���ӳɹ�
		if result then
			tclients[httpclientidx].sckconnected=true
			tclients[httpclientidx].sckreconncnt=0
			tclients[httpclientidx].sckreconncyclecnt=0
			--ֹͣ������ʱ��
			sys.timer_stop(reconn,idx)
			tclients[httpclientidx].connectedcb()
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--���ݷ��ͽ��������socket.send����첽�¼���
	elseif evt == "SEND" then
		if not result then
			print("error code")	     	
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		--������ʱʹ��
		if tclients[httpclientidx].mode then
			sys.timer_start(connectitem,RECONN_PERIOD*1000,httpclientidx)
		end
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		--������ʱʹ��
		if tclients[httpclientidx].mode then
			connectitem(httpclientidx)
		end
	--���������Ͽ�������socket.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		tclients[httpclientidx].sckconnected=false
		tclients[httpclientidx].httpconnected=false
		tclients[httpclientidx].sckconning = false
		if item=="USER" then
			if tclients[httpclientidx].discb then tclients[httpclientidx].discb(idx) end
			tclients[httpclientidx].discing = false
		end	
	--������ʱʹ��
		if tclients[httpclientidx].mode then
			connectitem(httpclientidx)
		end
	--���������Ͽ��������٣�����socket.close����첽�¼���
	elseif evt == "CLOSE" then
		local cb = tclients[httpclientidx].destroycb
		table.remove(tclients,httpclientidx)
		if cb then cb() end
	end
	--�������������Ͽ�������·����������
	if smatch((type(result)=="string") and result or "","ERROR") then
		socket.disconnect(idx)
	end
end

local function resetpara(httpclientidx)
	tclients[httpclientidx].statuscode=nil
	tclients[httpclientidx].rcvhead=nil
	tclients[httpclientidx].rcvbody=nil
	tclients[httpclientidx].status=nil
	tclients[httpclientidx].result=nil
	tclients[httpclientidx].data=""
end

--[[
��������timerfnc
���ܣ����������ݳ�ʱʱ������ʱ��
�������ͻ��˶�Ӧ��SOCKER��ID
����ֵ��
]]
function timerfnc(httpclientidx)
	tclients[httpclientidx].rcvcb(3)
	resetpara(httpclientidx)
end

--[[
�����������ݽ��մ�������
���ܣ������������ص����ݽ��д���
������idx���ͻ�������Ӧ�Ķ˿�ID data�����������ص�����
����ֵ����
]]
function rcv(idx,data)
    local httpclientidx = getclient(idx)
	--����һ����ʱ����ʱ��Ϊ10��
	sys.timer_start(timerfnc,10000,httpclientidx)
	--���û������
	if not data then 
		print("rcv: no data receive")
	--������ڽ��շ�������
	elseif tclients[httpclientidx].rcvcb then 
		--������������
		if not tclients[httpclientidx].data then tclients[httpclientidx].data="" end 
		tclients[httpclientidx].data=tclients[httpclientidx].data..data
		local h1,h2 = sfind(tclients[httpclientidx].data,"\r\n\r\n")
		if h1 and h2 then
			--�õ�״̬�к��ײ����ж�״̬
			--����״̬�к�����ͷ
			if sfind(tclients[httpclientidx].data,"\r\n\r\n") and not tclients[httpclientidx].status then 
				--����״̬���������Ϊ���´ξͲ���Ҫ���д˹���
				tclients[httpclientidx].status=true 
				local totil=ssub(tclients[httpclientidx].data,1,h2+1)
				tclients[httpclientidx].statuscode=smatch(totil,"%s(%d+)%s")
				tclients[httpclientidx].contentlen=tonumber(smatch(totil,":%s(%d+)\r\n"),10)
				local total=smatch(totil,"\r\n(.+\r\n)\r\n")
				--�ж�total�Ƿ�Ϊ��
				if total~="" then	
					if not tclients[httpclientidx].rcvhead then tclients[httpclientidx].rcvhead={} end
					for k,v in sgmatch(total,"(.-):%s(.-)\r\n") do
						if	v=="chunked"	then
							chunked=true
						end
						tclients[httpclientidx].rcvhead[k]=v
					end
				end
			end
			--����Ѿ��õ��ײ��Ҵ��ڽ��շ�������
			if	tclients[httpclientidx].rcvhead	and tclients[httpclientidx].rcvcb then
				--�Ƿ�ͷ��ΪTransfer-Encoding=chunked����������õ��Ƿֿ鴫�����
				if chunked then
					if sfind(ssub(tclients[httpclientidx].data,h2,-1),"\r\n%s-0%s-\r\n") then
						local chunkedbody = ""
						for k in sgmatch(ssub(tclients[httpclientidx].data,h2+1,-1),"%x-\r\n(.-)\r\n") do
							chunkedbody=chunkedbody..k
						end
						tclients[httpclientidx].rcvbody=chunkedbody
						tclients[httpclientidx].rcvcb(0,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead,tclients[httpclientidx].rcvbody)
						sys.timer_stop(timerfnc,httpclientidx)
						resetpara(httpclientidx)
						chunked=false
					end		
				--�Ƿ�õ�ʵ�壬�������������	
				elseif ssub(tclients[httpclientidx].data,h2+1,-1) then
					--��ʵ����ʵ�峤�ȵ���ʵ�ʳ���
					if slen(ssub(tclients[httpclientidx].data,h2+1,-1)) == tclients[httpclientidx].contentlen then
						tclients[httpclientidx].rcvcb(0,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead,ssub(tclients[httpclientidx].data,h2+1,-1))
						sys.timer_stop(timerfnc,httpclientidx)
						resetpara(httpclientidx)
					elseif slen(ssub(tclients[httpclientidx].data,h2+1,-1)) > tclients[httpclientidx].contentlen then
						--��ʵ����ʵ�峤�ȴ���ʵ�ʳ���
						tclients[httpclientidx].rcvcb(2,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead)
						sys.timer_stop(timerfnc,httpclientidx)
						resetpara(httpclientidx)										
					end
				--�����ײ�������ʵ�峤��Ϊ0
				elseif tclients[httpclientidx].contentlen==0 then
					tclients[httpclientidx].rcvcb(0,tclients[httpclientidx].statuscode,tclients[httpclientidx].rcvhead)
					sys.timer_stop(timerfnc,httpclientidx)
					resetpara(httpclientidx)
				end
			--��������û���շ�������	
			elseif not tclients[httpclientidx].rcvhead	then
				print("no message reback")
			else
				print("rcv",data)
			end
		else 
			print("error data format")
		end
	end
end


--[[
��������connect
����  ����������̨��������socket���ӣ�
        ������������Ѿ�׼���ã����������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�������
		rcv��socket�������ݵĴ�������
����  ��
		sckidx��socket idx
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function connect(sckidx,prot,host,port)
	socket.connect(sckidx,prot,host,port,ntfy,rcv)
	tclients[getclient(sckidx)].sckconning=true
end


--����Ԫ��ʱ����
local thttp = {}
thttp.__index = thttp

--[[
��������create
����  ������һ��http client
����  ��
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function create(host,port)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		host=host,
		port=port or 80,		
		sckidx=socket.SCK_MAX_CNT-#tclients-2,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		httpconnected=false,
		discing=false,
		status=false,
		rcvbody=nil,
		rcvhead={},
		result=nil,
		statuscode=nil,
		contentlen=nil
	}
	setmetatable(http_client,thttp)
	table.insert(tclients,http_client)
	return(http_client)
end

--[[
��������connect
����  ������http������
����  ��
        connectedcb:function���ͣ�socket connected �ɹ��ص�����	
		sckerrcb��function���ͣ�socket����ʧ�ܵĻص�����[��ѡ]
����ֵ����
]]
function thttp:connect(connectedcb,sckerrcb)
	self.connectedcb=connectedcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.httpconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port) 
    end
end

--[[
��������setconnectionmode
���ܣ���������ģʽ�������ӻ��Ƕ�����
������v��trueΪ�����ӣ�falseΪ������
���أ�
]]
function thttp:setconnectionmode(v)
	self.mode=v
end

--[[
��������disconnect
����  ���Ͽ�һ��http client�����ҶϿ�socket
����  ��
		discb��function���ͣ��Ͽ���Ļص�����[��ѡ]
����ֵ����
]]
function thttp:disconnect(discb)
	print("thttp:disconnect")
	self.discb=discb
	self.discing = true
	socket.disconnect(self.sckidx,"USER")
end

--[[
��������destroy
����  ������һ��http client
����  ��
		destroycb��function���ͣ�mqtt client���ٺ�Ļص�����[��ѡ]
����ֵ����
]]
function thttp:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socket.close(v.sckidx)
		end
	end
end

 
--[[
��������request
���ܣ��������������ϣ�Ȼ���������������
������cmdtyp:(���ͱ��ĵķ���������GET��POST)��rcvcb :�������ݵĻص�����,����rcvcb(result,statuscode,rcvhead,rcvbody)
url: ·�� ���磺"/"��ʾ��Ŀ¼�¡�head: table���ͣ���ֵ������XXXX :XXXX��ʽ������"Connection: keep-alive"��body: ʵ�����ݡ�
����ֵ����
]]
function thttp:request(cmdtyp,url,head,body,rcvcb)
	local val="" 
	--Ĭ�ϴ��ͷ�ʽΪ"GET"
	self.cmdtyp=cmdtyp or "GET"
	--Ĭ��Ϊ��Ŀ¼
	self.url=url or "/"
	--Ĭ��ʵ��Ϊ��
	self.body=body or ""
	self.rcvcb=rcvcb

	if not head or head=="" or (type(head)=="table" and #head==0) then
		self.head={"Connection: keep-alive", "Host: "..self.host}
	elseif type(head)=="table" and #head>0 then
		local connhead,hosthead,k,v
		for k,v in pairs(head) do
			if sfind(v,"Connection: ")==1 then connhead = true end
			if sfind(v,"Host: ")==1 then hosthead = true end
			table.insert(self.head,v)
		end
		if not hosthead then table.insert(self.head,1,"Host: "..self.host) end
		if not connhead then table.insert(self.head,1,"Connection: keep-alive") end
	else
		assert(false,"head format error")
	end
	
	val=cmdtyp.." "..self.url.." HTTP/1.1"..'\r\n'
	for k,v in pairs(self.head) do
		val=val..v..'\r\n'
	end
	if self.body then 
		val=val.."\r\n"..self.body
	end		
	snd(self.sckidx,val,cmdtyp)	
end

--[[
��������getstatus
����  ����ȡHTTP CLIENT��״̬
����  ����
����ֵ��HTTP CLIENT��״̬��string���ͣ���3��״̬��
		DISCONNECTED��δ����״̬
		CONNECTING��������״̬
		CONNECTED������״̬
]]
function thttp:getstatus()
	if self.httpconnected then
		return "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	elseif self.disconnect then
		return "DISCONNECTED"
	end
end
