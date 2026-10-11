"""Independent binary glTF validation. Requires numpy; writes a JSON report."""
import json, struct, os, hashlib, numpy as np
ROOT=os.path.dirname(os.path.abspath(__file__))
def read_glb(name):
    data=open(os.path.join(ROOT,name),'rb').read()
    magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and total==len(data)
    pos=12;doc=None;binary=None
    while pos<len(data):
        length,kind=struct.unpack_from('<II',data,pos);pos+=8
        payload=data[pos:pos+length];pos+=length
        if kind==0x4e4f534a:doc=json.loads(payload)
        if kind==0x004e4942:binary=payload
    return doc,binary
def accessor(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
    components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    stride=view.get('byteStride',np.dtype(dtype).itemsize*components)
    array=np.ndarray((a['count'],components),dtype=dtype,buffer=binary,offset=start,strides=(stride,np.dtype(dtype).itemsize)).copy()
    assert np.isfinite(array).all()
    return array
def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1])
    r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    m=np.eye(4);m[:3,:3]=r@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
def world_matrices(doc):
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    cache={}
    def world(i):
        if i not in cache:cache[i]=(world(parents[i]) if i in parents else np.eye(4))@matrix(doc['nodes'][i])
        return cache[i]
    return [world(i) for i in range(len(doc['nodes']))],parents
